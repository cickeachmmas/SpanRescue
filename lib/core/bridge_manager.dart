// ═══════════════════════════════════════════════════════
// bridge_manager.dart — Multi-Group TCP Bridge
// يربط مجموعات Wi-Fi Direct ببعضها عبر TCP مستمر
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/mesh_message.dart';
import '../models/group_info.dart';
import 'mesh_service.dart';

class BridgeManager {
  static const int bridgePort = 8889;

  // Bridges النشطة: groupId → Socket
  final Map<String, Socket> _bridges = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};

  ServerSocket? _bridgeServer;
  late MeshService _meshService;

  void setMeshService(MeshService service) => _meshService = service;

  // ─── فتح Bridge Server (للـ GO فقط) ─────────────
  Future<void> startBridgeServer({int port = bridgePort}) async {
    try {
      try {
        _bridgeServer = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
        );
      } catch (e) {
        // Some platforms may require 'shared' bind when multiple listeners exist
        _meshService.addLog('BRIDGE SERVER BIND failed, retrying with shared=true: $e', LogLevel.warning);
        _bridgeServer = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
      }
      _meshService.addLog(
        'BRIDGE SERVER: Listening on :$port',
        LogLevel.info,
      );

      _bridgeServer!.listen((socket) {
        final remoteIp = socket.remoteAddress.address;
        _meshService.addLog(
          'BRIDGE INCOMING: connection from $remoteIp',
          LogLevel.info,
        );
        _handleBridgeSocket(socket, remoteIp);
      });
    } catch (e) {
      _meshService.addLog('BRIDGE SERVER ERROR: $e', LogLevel.error);
    }
  }

  // ─── الاتصال بـ Bridge مجموعة أخرى ──────────────
  Future<void> connectToBridge(GroupInfo remoteGroup) async {
    // لا تتصل بنفسك
    if (remoteGroup.groupId == _meshService.myGroupId) return;

    // هل متصل بالفعل؟
    if (_bridges.containsKey(remoteGroup.groupId)) return;

    _meshService.addLog(
      'BRIDGE CONNECTING: ${remoteGroup.groupId} @ '
      '${remoteGroup.goIpAddress}:${remoteGroup.bridgePort}',
      LogLevel.info,
    );

    try {
      final socket = await Socket.connect(
        remoteGroup.goIpAddress,
        remoteGroup.bridgePort,
        timeout: const Duration(seconds: 10),
      );

      _bridges[remoteGroup.groupId] = socket;
      _retryCounts[remoteGroup.groupId] = 0;

      _meshService.addLog(
        'BRIDGE ESTABLISHED: ${_meshService.myGroupId} ↔ ${remoteGroup.groupId}',
        LogLevel.info,
      );

      _handleBridgeSocket(socket, remoteGroup.groupId);

      socket.done.then((_) {
        _onBridgeDisconnected(remoteGroup);
      });
    } catch (e) {
      _meshService.addLog(
        'BRIDGE CONNECT FAILED: ${remoteGroup.groupId} → $e',
        LogLevel.error,
      );
      _scheduleBridgeRetry(remoteGroup);
    }
  }

  // ─── معالجة Socket Bridge ─────────────────────────
  void _handleBridgeSocket(Socket socket, String sourceId) {
    final buffer = StringBuffer();

    socket.listen(
      (data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        final raw = buffer.toString();
        final lines = raw.split('\n');

        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            _meshService.addLog(
              '📩 BRIDGE MSG from $sourceId',
              LogLevel.debug,
            );
            _meshService.processIncoming(line);
          }
        }

        buffer.clear();
        buffer.write(lines.last);
      },
      onError: (e) {
        _meshService.addLog('BRIDGE SOCKET ERROR: $e', LogLevel.error);
        socket.destroy();
      },
      onDone: () {
        _bridges.removeWhere((_, s) => s == socket);
      },
    );
  }

  // ─── إرسال لكل Bridges ───────────────────────────
  void broadcastToBridges(MeshMessage message) {
    final raw = '${message.toJsonString()}\n';
    final bytes = utf8.encode(raw);

    final failed = <String>[];

    for (final entry in _bridges.entries) {
      // لا ترسل لمجموعة رأت الرسالة بالفعل
      if (message.seenBy.contains(entry.key)) continue;

      try {
        entry.value.add(bytes);
        _meshService.addLog(
          'BRIDGE FORWARD → ${entry.key}: ${message.messageId.substring(0, 8)}',
          LogLevel.debug,
        );
      } catch (e) {
        failed.add(entry.key);
        _meshService.addLog(
          'BRIDGE SEND FAILED → ${entry.key}: $e',
          LogLevel.error,
        );
      }
    }

    for (final id in failed) {
      _bridges.remove(id);
    }
  }

  // ─── إرسال خام لكل Bridges ───────────────────────
  void broadcastRaw(String raw) {
    final line = raw.endsWith('\n') ? raw : '$raw\n';
    final bytes = utf8.encode(line);

    final failed = <String>[];
    for (final entry in _bridges.entries) {
      try {
        entry.value.add(bytes);
        _meshService.addLog(
          'BRIDGE RAW FORWARD → ${entry.key}',
          LogLevel.debug,
        );
      } catch (e) {
        failed.add(entry.key);
        _meshService.addLog(
          'BRIDGE RAW SEND FAILED → ${entry.key}: $e',
          LogLevel.error,
        );
      }
    }

    for (final id in failed) {
      _bridges.remove(id);
    }
  }

  // ─── إعادة المحاولة عند الانقطاع ─────────────────
  void _onBridgeDisconnected(GroupInfo remoteGroup) {
    _bridges.remove(remoteGroup.groupId);
    _meshService.addLog(
      'BRIDGE DISCONNECTED: ${remoteGroup.groupId}',
      LogLevel.warning,
    );
    _scheduleBridgeRetry(remoteGroup);
  }

  void _scheduleBridgeRetry(GroupInfo remoteGroup) {
    final count = (_retryCounts[remoteGroup.groupId] ?? 0) + 1;
    _retryCounts[remoteGroup.groupId] = count;

    // Exponential backoff: 15s, 30s, 60s max
    final delay = Duration(seconds: (15 * count).clamp(15, 60));

    _meshService.addLog(
      'BRIDGE RETRY scheduled: ${remoteGroup.groupId} in ${delay.inSeconds}s (attempt $count)',
      LogLevel.warning,
    );

    _retryTimers[remoteGroup.groupId]?.cancel();
    _retryTimers[remoteGroup.groupId] = Timer(delay, () {
      connectToBridge(remoteGroup);
    });
  }

  // ─── حالة الـ Bridges ─────────────────────────────
  int get activeBridgeCount => _bridges.length;
  List<String> get connectedGroupIds => _bridges.keys.toList();

  bool isConnectedTo(String groupId) => _bridges.containsKey(groupId);

  // ─── إيقاف ───────────────────────────────────────
  Future<void> stop() async {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    for (final s in _bridges.values) {
      s.destroy();
    }
    _bridges.clear();
    _bridgeServer?.close();
    _bridgeServer = null;
  }
}
