// ═══════════════════════════════════════════════════════
// main.dart — نقطة الدخول الكاملة مع ربط كل الخدمات
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'core/mesh_service.dart';
import 'core/wifi_direct_service.dart';
import 'core/mesh_router.dart';
import 'core/bridge_manager.dart';
import 'core/store_forward_queue.dart';
import 'core/beacon_service.dart';
import 'core/audio_service.dart';
import 'core/notification_service.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  // إنشاء Node ID فريد عند أول تشغيل
  if (!prefs.containsKey('nodeId')) {
    final rnd = Random().nextInt(899999) + 100000;
    await prefs.setString('nodeId', 'Node_$rnd');
  }

  runApp(SpanRescueApp(prefs: prefs));
}

// ═══════════════════════════════════════════════════════
class SpanRescueApp extends StatelessWidget {
  final SharedPreferences prefs;
  const SpanRescueApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MeshService(prefs)),
        Provider(create: (_) => MeshRouter()),
        Provider(create: (_) => StoreForwardQueue(prefs)),
        Provider(create: (_) => BridgeManager()),
        Provider(create: (_) => WifiDirectService()),
        Provider(create: (_) => BeaconService()),
        Provider(create: (_) => AudioService()),
        Provider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'SPAN Rescue',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppInitializer(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AppInitializer — يربط كل الخدمات ويطلب الصلاحيات
// ═══════════════════════════════════════════════════════
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});
  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  String _status = 'جاري التهيئة...';
  double _progress = 0.0;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initialize();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String msg, double progress) async {
    if (!mounted) return;
    setState(() { _status = msg; _progress = progress; });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _initialize() async {
    await _setStatus('طلب الصلاحيات...', 0.1);
    await _requestAllPermissions();

    await _setStatus('تهيئة خدمات الشبكة...', 0.3);
    final mesh        = context.read<MeshService>();
    final router      = context.read<MeshRouter>();
    final queue       = context.read<StoreForwardQueue>();
    final bridge      = context.read<BridgeManager>();
    final wifi        = context.read<WifiDirectService>();
    final beacon      = context.read<BeaconService>();
    final audio       = context.read<AudioService>();
    final notif       = context.read<NotificationService>();

    // ── ربط كل الخدمات ببعض ──────────────────────────
    await _setStatus('ربط الخدمات...', 0.5);

    bridge.setMeshService(mesh);
    queue.flushWithCallback; // تفعيل
    wifi.setMeshService(mesh);
    wifi.setQueue(queue);
    wifi.setBridgeManager(bridge);
    beacon.setMeshService(mesh);
    audio.setMeshService(mesh);
    notif.setMeshService(mesh);

    // ── تهيئة الإشعارات ──────────────────────────────
    await _setStatus('تهيئة الإشعارات...', 0.6);
    await notif.initialize();

    // ── الاستماع لـ SOS لإطلاق إشعار فوري ──────────
    mesh.onSOS.listen((sos) => notif.showSOSNotification(sos));
    mesh.onMessage.listen((msg) {
      if (!msg.isSOS && !msg.isBeacon) {
        notif.showMessageNotification(msg);
      }
    });

    // ── تهيئة MeshService ─────────────────────────────
    await _setStatus('تهيئة شبكة Mesh...', 0.7);
    await mesh.initialize();

    // ── تتبع GPS ──────────────────────────────────────
    await _setStatus('تفعيل GPS...', 0.8);
    _startGPSTracking(mesh);

    // ── تتبع البطارية ─────────────────────────────────
    _startBatteryTracking(mesh);

    // ── ربط Beacon callbacks ─────────────────────────
    beacon.onBeaconReady = (b) => wifi.broadcastMessage(b);
    beacon.onGOBeaconReady = (g) {
      final raw = jsonEncode(g.toJson());
      wifi.broadcastRaw(raw);
    };

    // ── بدء Wi-Fi Direct ─────────────────────────────
    await _setStatus('بدء Wi-Fi Direct...', 0.9);
    await wifi.start();

    // ── بدء Beacon ───────────────────────────────────
    beacon.start();

    await _setStatus('الشبكة جاهزة ✓', 1.0);
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) setState(() => _ready = true);
  }

  // ─── طلب كل الصلاحيات ────────────────────────────
  Future<void> _requestAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
      Permission.microphone,
      Permission.notification,
      Permission.storage,
    ];

    for (final p in permissions) {
      await p.request();
    }
  }

  // ─── تتبع GPS ─────────────────────────────────────
  void _startGPSTracking(MeshService mesh) {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      mesh.updateMyLocation(pos.latitude, pos.longitude);
    });
  }

  // ─── تتبع البطارية ───────────────────────────────
  void _startBatteryTracking(MeshService mesh) {
    final battery = Battery();
    Timer.periodic(const Duration(minutes: 1), (_) async {
      final level = await battery.batteryLevel;
      mesh.updateMyBattery(level);
    });
    // أول قراءة فورية
    battery.batteryLevel.then((l) => mesh.updateMyBattery(l));
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MainShell();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Stack(
        children: [
          // خلفية نقاط الشبكة
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // شعار
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentCyan
                            .withOpacity(0.5 + 0.5 * _glowController.value),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan
                              .withOpacity(0.2 * _glowController.value),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: AppTheme.accentCyan,
                      size: 55,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // عنوان
                const Text(
                  'SPAN RESCUE',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyan,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tactical Mesh Network',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 56),

                // شريط التقدم
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: const Color(0xFF111111),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentCyan,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _status,
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // معلومات الإصدار
                Text(
                  'v1.0.0 — Field Ready',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    color: AppTheme.textMuted.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── خلفية نقاط الشبكة ───────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint..color = const Color(0xFF111111));
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
