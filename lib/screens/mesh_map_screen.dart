// ═══════════════════════════════════════════════════════
// mesh_map_screen.dart — Screen 1: الخريطة التكتيكية
// Offline OSM Map + Radar العسكري + SOS Button
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../core/mesh_service.dart';
import '../models/node_info.dart';
import '../models/mesh_message.dart';
import '../theme/app_theme.dart';
import '../widgets/simulation/simulation_sheet.dart';
import '../widgets/map/radar_overlay.dart';
import '../widgets/map/sos_button.dart';
import '../widgets/map/nodes_directory_sheet.dart';
import '../core/geo_utils.dart';

class MeshMapScreen extends StatefulWidget {
  const MeshMapScreen({super.key});

  @override
  State<MeshMapScreen> createState() => _MeshMapScreenState();
}

class _MeshMapScreenState extends State<MeshMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _myPosition = const LatLng(35.3034, 4.1754); // موقع افتراضي
  bool _mapReady = false;
  StreamSubscription<Position>? _locationSub;

  // Animation للـ SOS button
  late AnimationController _sosAnimController;
  late Animation<double> _sosAnimation;

  @override
  void initState() {
    super.initState();
    _initSOSAnimation();
    _startLocationUpdates();
  }

  void _initSOSAnimation() {
    _sosAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _sosAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _sosAnimController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startLocationUpdates() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      setState(() {
        _myPosition = LatLng(position.latitude, position.longitude);
      });

      if (mounted) {
        context.read<MeshService>().updateMyLocation(
          position.latitude,
          position.longitude,
        );

        if (_mapReady) {
          _mapController.move(_myPosition, _mapController.camera.zoom);
        }
      }
    });
  }

  @override
  void dispose() {
    _sosAnimController.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Stack(
        children: [
          // ── الخريطة الأساسية ──────────────────────
          _buildMap(),

          // ── AppBar مخصص شفاف ─────────────────────
          _buildTransparentAppBar(),

          // ── زر الأشخاص (Nodes Directory) ──────────
          _buildTeamButton(),

          // ── زر SOS النابض ─────────────────────────
          _buildSOSButtonWidget(),

          // ── الرادار العسكري ───────────────────────
          _buildRadar(),
        ],
      ),
    );
  }

  // ─── الخريطة ─────────────────────────────────────
  Widget _buildMap() {
    return Consumer<MeshService>(
      builder: (context, mesh, _) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _myPosition,
            initialZoom: 15.0,
            minZoom: 10.0,
            maxZoom: 18.0,
            onMapReady: () => setState(() => _mapReady = true),
          ),
          children: [
            // Tiles من الـ Cache المحلي
            TileLayer(
              urlTemplate: 'assets/map_tiles/{z}/{x}/{y}.png',
              fallbackUrl:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.spanrescue.tactical',
              tileBuilder: _darkTileBuilder,
            ),

            // ── Markers الأجهزة الأخرى ─────────────
            MarkerLayer(
              markers: _buildNodeMarkers(mesh),
            ),

            // ── Marker موقعي ──────────────────────
            MarkerLayer(
              markers: [_buildMyMarker()],
            ),
          ],
        );
      },
    );
  }

  // تحويل الخريطة لوضع داكن
  Widget _darkTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.2, 0, 0, 0, 50,
        0, -0.2, 0, 0, 50,
        0, 0, -0.2, 0, 50,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  // ─── Marker جهازي ────────────────────────────────
  Marker _buildMyMarker() {
    return Marker(
      point: _myPosition,
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دائرة خارجية نابضة
          AnimatedBuilder(
            animation: _sosAnimController,
            builder: (_, __) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentCyan.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
          ),
          // دائرة داخلية
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentCyan,
              boxShadow: AppTheme.cyanGlow,
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.black,
              size: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Markers الأجهزة الأخرى ──────────────────────
  List<Marker> _buildNodeMarkers(MeshService mesh) {
    final markers = <Marker>[];

    for (final node in mesh.onlineNodes) {
      GeoLocation loc = node.location;

      // Geo-Interpolation إذا GPS مفقود
      if (loc.isGpsDenied) {
        loc = GeoUtils.interpolatePosition(
          rescuerLocation: mesh.myLocation,
          victimNodeId: node.nodeId,
        );
      }

      if (loc.lat == 0.0 && loc.lng == 0.0) continue;

      final color = node.isCritical
          ? AppTheme.accentRed
          : node.isVictim
              ? AppTheme.accentOrange
              : AppTheme.accentCyan;

      markers.add(
        Marker(
          point: LatLng(loc.lat, loc.lng),
          width: 44,
          height: 54,
          child: GestureDetector(
            onTap: () => _showNodeInfo(node),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    node.isVictim
                        ? Icons.personal_injury
                        : Icons.medical_services,
                    color: color,
                    size: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.nodeId.replaceAll('Node_', ''),
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ─── AppBar شفاف ─────────────────────────────────
  Widget _buildTransparentAppBar() {
    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.radar, color: AppTheme.accentCyan, size: 20),
            const SizedBox(width: 8),
            const Text(
              'SPAN Mesh Tactical',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.developer_board, color: AppTheme.accentCyan),
              onPressed: () => showSimulationSheet(context, context.read<MeshService>()),
              tooltip: 'Simulation',
            ),
            Consumer<MeshService>(
              builder: (_, mesh, __) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentGreen.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${mesh.onlineNodes.length} NODES',
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.accentGreen,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── زر الفريق (Nodes Directory) ─────────────────
  Widget _buildTeamButton() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      right: 16,
      top: topPadding + 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showNodesDirectory,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.group,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  // ─── زر SOS ──────────────────────────────────────
  Widget _buildSOSButtonWidget() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      right: 16,
      top: topPadding + 192,
      child: SOSButton(
        onPressed: _triggerSOS,
        animation: _sosAnimation,
      ),
    );
  }

  // ─── الرادار ──────────────────────────────────────
  Widget _buildRadar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Consumer<MeshService>(
        builder: (context, mesh, _) {
          return RadarOverlay(
            myLocation: mesh.myLocation,
            nodes: mesh.onlineNodes,
          );
        },
      ),
    );
  }

  // ─── تشغيل SOS ───────────────────────────────────
  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.accentRed, width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed),
            SizedBox(width: 8),
            Text(
              'إرسال استغاثة؟',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'سيصل نداء الاستغاثة لكل الأجهزة في الشبكة فوراً.',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MeshService>().createSOSMessage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'إرسال SOS',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── عرض معلومات العقدة ──────────────────────────
  void _showNodeInfo(NodeInfo node) {
    final mesh = context.read<MeshService>();
    final distance = mesh.distanceTo(node);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NodeInfoSheet(node: node, distance: distance),
    );
  }

  // ─── عرض قائمة الأجهزة ───────────────────────────
  void _showNodesDirectory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NodesDirectorySheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════
// _NodeInfoSheet — معلومات عقدة من الـ Map
// ═══════════════════════════════════════════════════════
class _NodeInfoSheet extends StatelessWidget {
  final NodeInfo node;
  final double distance;

  const _NodeInfoSheet({required this.node, required this.distance});

  @override
  Widget build(BuildContext context) {
    final color = node.isCritical ? AppTheme.accentRed : AppTheme.accentCyan;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(Icons.add, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                node.nodeId,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),

          const Divider(color: Color(0xFF1A1A1A), height: 24),

          // Info rows
          _infoRow(Icons.battery_full, 'Battery',
              '${node.battery}%', _batteryColor(node.battery)),
          _infoRow(Icons.my_location, 'Distance',
              GeoUtils.formatDistance(distance), AppTheme.accentCyan),
          _infoRow(Icons.work, 'Role',
              node.role.name.toUpperCase(),
              node.isVictim ? AppTheme.accentRed : AppTheme.accentGreen),
          _infoRow(Icons.medical_services, 'Triage',
              node.triageState.name.toUpperCase(),
              _triageColor(node.triageState)),
          _infoRow(Icons.device_hub, 'Via',
              node.discoveredVia ?? 'Direct', AppTheme.textSecondary),
          _infoRow(Icons.access_time, 'Last Seen',
              node.lastSeenText, AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int level) {
    if (level > 50) return AppTheme.accentGreen;
    if (level > 20) return AppTheme.accentYellow;
    return AppTheme.accentRed;
  }

  Color _triageColor(TriageState state) {
    switch (state) {
      case TriageState.red: return AppTheme.accentRed;
      case TriageState.yellow: return AppTheme.accentYellow;
      case TriageState.green: return AppTheme.accentGreen;
      default: return AppTheme.textSecondary;
    }
  }
}
