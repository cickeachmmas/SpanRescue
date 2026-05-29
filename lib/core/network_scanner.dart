// ═══════════════════════════════════════════════════════
// network_scanner.dart — مكتشف الأجهزة على الشبكة
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

enum DeviceType {
  appActive,      // يشغل التطبيق + Wi-Fi
  wifiOnly,       // Wi-Fi فقط بدون التطبيق
}

class NetworkDevice {
  final String ipAddress;
  final String? hostName;
  final DeviceType type;
  final bool isReachable;
  final int port;

  NetworkDevice({
    required this.ipAddress,
    required this.hostName,
    required this.type,
    required this.isReachable,
    this.port = 8888,
  });

  @override
  String toString() => '$ipAddress ${hostName ?? "Unknown"}';
}

class NetworkScanner {
  final NetworkInfo _networkInfo = NetworkInfo();
  final int meshPort = 8888;

  // Use a limited concurrency pool to avoid spawning too many sockets
  // at once which can cause resource pressure and UI stalls.
  static const int _concurrency = 32;

  // ─── اكتشاف الشبكة المحلية (محسن) ─────────────────
  Future<List<NetworkDevice>> scanNetwork() async {
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (wifiIp == null) return [];

      final subnet = _getSubnet(wifiIp);
      final devices = <NetworkDevice>[];

      // Generate target IPs (skip our own IP quickly)
      final parts = wifiIp.split('.');
      final myLast = int.tryParse(parts.last) ?? -1;
      final ips = <String>[];
      for (int i = 1; i <= 254; i++) {
        if (i == myLast) continue;
        ips.add('$subnet.$i');
      }

      // Process in batches to limit concurrent socket connects
      for (var i = 0; i < ips.length; i += _concurrency) {
        final batch = ips.sublist(i, (i + _concurrency).clamp(0, ips.length));
        final futures = batch.map((ip) => _probeDevice(ip)).toList();
        final results = await Future.wait(futures);
        devices.addAll(results.whereType<NetworkDevice>());
        // Yield briefly to the event loop
        await Future.delayed(const Duration(milliseconds: 20));
      }

      return devices;
    } catch (e) {
      // Don't crash the UI — return empty on errors
      return [];
    }
  }

  // ─── اختبار جهاز واحد (خالي من استدعاءات Process.run) ───
  Future<NetworkDevice?> _probeDevice(String ipAddress) async {
    try {
      // محاولة الاتصال ببورت التطبيق بسرعة (200ms)
      final socket = await Socket.connect(
        ipAddress,
        meshPort,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();

      return NetworkDevice(
        ipAddress: ipAddress,
        hostName: null,
        type: DeviceType.appActive,
        isReachable: true,
      );
    } catch (e) {
      // لا نحاول الآن استدعاء أوامر نظامية (ping/nslookup)
      // لتجنب مشاكل في الأداء أو صلاحيات على الجوال.
      // بدل ذلك نجرب اتصال TCP قصير لبورتات شائعة كدليل على وجود الجهاز
      try {
        final ports = [80, 443];
        for (final p in ports) {
          try {
            final s = await Socket.connect(
              ipAddress,
              p,
              timeout: const Duration(milliseconds: 180),
            );
            s.destroy();
            return NetworkDevice(
              ipAddress: ipAddress,
              hostName: null,
              type: DeviceType.wifiOnly,
              isReachable: true,
            );
          } catch (_) {}
        }
      } catch (_) {}
      return null;
    }
  }

  // ─── استخراج subnet من IP ──────────────────────
  String _getSubnet(String ipAddress) {
    final parts = ipAddress.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
