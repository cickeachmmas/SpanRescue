// ═══════════════════════════════════════════════════════
// beacon_service.dart — نبضات الحياة كل 15 ثانية
// يُحدِّث الشبكة بمعلومات الجهاز باستمرار
// ═══════════════════════════════════════════════════════

import 'dart:async';

import '../models/mesh_message.dart';
import '../models/group_info.dart';
import 'mesh_service.dart';
import 'geo_utils.dart';

class BeaconService {
  static const Duration _beaconInterval = Duration(seconds: 15);
  static const Duration _goBeaconInterval = Duration(seconds: 15);

  Timer? _beaconTimer;
  Timer? _goBeaconTimer;
  Timer? _cleanupTimer;

  late MeshService _meshService;
  Function(MeshMessage)? onBeaconReady;       // callback لإرسال الـ Beacon
  Function(GroupInfo)? onGOBeaconReady;       // callback لإرسال GO Beacon

  void setMeshService(MeshService service) => _meshService = service;

  // ─── بدء الخدمة ──────────────────────────────────
  void start() {
    _meshService.addLog('BEACON SERVICE: Started (interval: 15s)', LogLevel.info);

    // Beacon عادي كل 15 ثانية
    _beaconTimer = Timer.periodic(_beaconInterval, (_) => _sendBeacon());
    _sendBeacon(); // أول نبضة فوراً

    // GO Beacon كل 15 ثانية (إذا كنت GO)
    _goBeaconTimer = Timer.periodic(_goBeaconInterval, (_) {
      if (_meshService.isGroupOwner) {
        _sendGOBeacon();
      }
    });

    // تنظيف العقد المنقطعة كل 45 ثانية
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _cleanupOfflineNodes(),
    );
  }

  // ─── إرسال Beacon عادي ───────────────────────────
  void _sendBeacon() {
    final beacon = _meshService.createBeacon();
    onBeaconReady?.call(beacon);

    _meshService.addLog(
      'BEACON SENT: '
      'Battery:${_meshService.myBattery}% '
      'Role:${_meshService.myRole.name.toUpperCase()} '
      'GPS:(${_meshService.myLocation.lat.toStringAsFixed(4)},'
      '${_meshService.myLocation.lng.toStringAsFixed(4)})',
      LogLevel.debug,
    );
  }

  // ─── إرسال GO Beacon للـ Bridge Discovery ─────────
  void _sendGOBeacon() {
    final group = GroupInfo(
      groupId: _meshService.myGroupId,
      goNodeId: _meshService.myNodeId,
      goIpAddress: _meshService.myIpAddress,
      bridgePort: 8889,
      memberCount: _meshService.connectedNodes.length + 1,
      lat: _meshService.myLocation.lat,
      lng: _meshService.myLocation.lng,
      lastBeaconTimestamp: DateTime.now().millisecondsSinceEpoch,
    );

    onGOBeaconReady?.call(group);

    _meshService.addLog(
      'GO_BEACON SENT: ${group.groupId} '
      'Members:${group.memberCount} '
      'IP:${group.goIpAddress}:${group.bridgePort}',
      LogLevel.debug,
    );
  }

  // ─── حذف العقد المنقطعة ───────────────────────────
  void _cleanupOfflineNodes() {
    final offline = _meshService.connectedNodes.entries
        .where((e) => !e.value.isOnline)
        .map((e) => e.key)
        .toList();

    for (final nodeId in offline) {
      _meshService.connectedNodes.remove(nodeId);
      _meshService.addLog(
        'BEACON TIMEOUT: $nodeId marked OFFLINE (45s)',
        LogLevel.warning,
      );

      // Geo-Interpolation تلقائي إذا كانت ضحية
      final node = _meshService.connectedNodes[nodeId];
      if (node != null && node.isVictim) {
        _meshService.addLog(
          'GEO-INTERPOLATION: $nodeId placed at estimated position',
          LogLevel.info,
        );
      }
    }

    if (offline.isNotEmpty) {
      _meshService.refreshNetwork();
    }
  }

  // ─── إيقاف ───────────────────────────────────────
  void stop() {
    _beaconTimer?.cancel();
    _goBeaconTimer?.cancel();
    _cleanupTimer?.cancel();
    _meshService.addLog('BEACON SERVICE: Stopped', LogLevel.info);
  }
}
