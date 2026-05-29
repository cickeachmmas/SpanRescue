// ═══════════════════════════════════════════════════════
// wifi_direct_service.dart — Layer 4: Hardware Edge
// Wi-Fi Direct + TCP Sockets + Auto Group Owner Election
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../p2p_helper.dart';
import '../models/mesh_message.dart';
import '../models/group_info.dart';
import 'mesh_service.dart';
import 'store_forward_queue.dart';
import 'bridge_manager.dart';
import 'mesh_router.dart';

class WifiDirectService {
  // Ports
  static const int clientPort  = 8888; // Client ↔ GO
  static const int bridgePort  = 8889; // GO ↔ GO Bridge

  // الحالة
  bool _isGroupOwner = false;
  bool _isRunning = false;
  String _myIp = '';
  String _p2pIp = '';
  // Temporary testing fallback: bind server to WLAN IPv4 to allow PC<->device tests
  // This should remain off for real Wi-Fi Direct group traffic.
    // If true, bind servers to wlan0 when p2p is not available.
    // Enabled to provide a robust fallback when device Wi‑Fi Direct is unavailable.
    bool _useWifiFallback = true;
  String _wlanIp = '';

  // Flutter P2P Plugin
  final FlutterP2pConnection _p2p = FlutterP2pConnection();
  // Platform channel to control Android foreground service
  static const MethodChannel _platform = MethodChannel('com.spanrescue.tactical/foreground');

  // TCP Server للـ Clients
  ServerSocket? _clientServer;

  // قائمة الـ Clients المتصلين حالياً (LinkedHashMap للحفاظ على ترتيب الإدخال)
  final LinkedHashMap<String, Socket> _clientSockets = LinkedHashMap();
  final Map<String, DateTime> _clientLastActive = {};

  // حدود وإعدادات إدارة السوكيت
  static const int _maxClients = 64;
  Timer? _socketCleanupTimer;
  // Track ongoing outgoing connect attempts to avoid duplicates and overload
  final Set<String> _ongoingConnects = <String>{};
  // Track P2P connect attempts (plugin-level)
  final Set<String> _ongoingP2pConnects = <String>{};

  // المراجع الخارجية
  late MeshService _meshService;
  late StoreForwardQueue _queue;
  late BridgeManager _bridgeManager;

  // Timer للـ Discovery كل 15 ثانية
  Timer? _discoveryTimer;
  Timer? _beaconTimer;
  // UDP app-level beacon (APP_BEACON) — helps identify devices running the app
  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  static const int _udpPort = 44444;
  // JSON parsing queue (batch -> single compute call)
  final List<Map<String, String>> _jsonQueue = [];
  Timer? _jsonFlushTimer;
  static const Duration _jsonFlushInterval = Duration(milliseconds: 150);

  // Seen GO beacon timestamps to prevent useless loops
  final Map<String, int> _seenGoBeaconTimestamps = {};

  // ─── تشغيل الخدمة ────────────────────────────────
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    _meshService.addLog('START WIFI DIRECT NETWORK', LogLevel.info);

    // طلب الصلاحيات
    await _requestPermissions();

    // تحقق من صلاحيات أساسية وبلغ السجل إن لم تكن ممنوحة
    try {
      final loc = await Permission.location.status;
      final near = await Permission.nearbyWifiDevices.status;
      if (!loc.isGranted || !near.isGranted) {
        _meshService.addLog('WARNING: required permissions not granted (location:${loc.isGranted}, nearby:${near.isGranted})', LogLevel.warning);
      }
    } catch (_) {}

    // تهيئة الـ Plugin
    await _p2p.initialize();
    await _p2p.register();

    // محاولة اكتشاف عناوين IP محلية حتى قبل البث
    try {
      _wlanIp = await _getLocalIPv4();
      _p2pIp = await _findP2pIPv4();
      _meshService.addLog('IP AUTO-DETECT: wlan=$_wlanIp p2p=$_p2pIp', LogLevel.debug);
    } catch (e) {
      _meshService.addLog('IP AUTO-DETECT ERROR: $e', LogLevel.debug);
    }

    // الاستماع للأحداث
    _p2p.streamWifiP2PInfo().listen(_onP2PInfoChanged);
    _p2p.streamPeers().listen(_onPeersChanged);

    // بدء الـ Discovery
    _startDiscoveryLoop();

    // بدء UDP listener + beacon loop for app presence
    _startUdpListener();
    _startUdpBeaconLoop();

    // Start Android foreground service if available
    if (!kIsWeb) {
      try {
        await _platform.invokeMethod('startService');
        _meshService.addLog('REQUESTED: start foreground service', LogLevel.info);
      } catch (e) {
        _meshService.addLog('START SERVICE ERROR: $e', LogLevel.error);
      }
    }

    // بدء Beacon كل 15 ثانية
    _startBeaconLoop();

    // بدء تنظيف السوكيت الدوري
    _startSocketCleanupTimer();

    // If developer enabled wifi-fallback testing mode, start TCP server on WLAN IP
    if (_useWifiFallback) {
      try {
        _wlanIp = await _getLocalIPv4();
        _meshService.addLog('WIFI FALLBACK: detected wlan IP=$_wlanIp; starting TCP server for testing', LogLevel.info);
        await _startClientTCPServer();
      } catch (e) {
        _meshService.addLog('WIFI FALLBACK ERROR: $e', LogLevel.warning);
      }
    }
  }

  /// Enable or disable the temporary wifi fallback mode used for PC<->device testing.
  /// When enabled the service will attempt to bind the client TCP server to the
  /// device's primary IPv4 (wlan) so a PC on the same Wi‑Fi can connect.
  void enableWifiFallback(bool enable) {
    _useWifiFallback = enable;
  }

  // Simple peers-changed handler (plugin emits peer lists)
  void _onPeersChanged(dynamic peers) {
    try {
      _meshService.addLog('PEERS CHANGED: ${peers?.toString() ?? 'null'}', LogLevel.debug);
    } catch (_) {}

    // Attempt to request P2P connection to discovered peers so groups form
    try {
      if (peers is List) {
        for (final p in peers) {
          try {
            final deviceName = p is Map ? p['deviceName'] ?? p['name'] ?? '' : p.deviceName ?? '';
            final rawAddr = p is Map
                ? (p['deviceAddress'] ?? p['deviceMacAddress'] ?? p['macAddress'] ?? p['address'])
                : null;
            if (rawAddr == null) continue;
            final deviceAddr = rawAddr.toString();
            if (deviceAddr.isEmpty) continue;
            final addr = deviceAddr;
            if (_ongoingP2pConnects.contains(addr)) continue;
            _ongoingP2pConnects.add(addr);
            _meshService.addLog('P2P: attempting plugin connect to $deviceName ($addr)', LogLevel.info);
            _p2p.connect(addr).then((ok) {
              _meshService.addLog('P2P connect result for $addr: $ok', LogLevel.debug);
            }).catchError((e) {
              _meshService.addLog('P2P connect error to $addr: $e', LogLevel.warning);
            }).whenComplete(() {
              _ongoingP2pConnects.remove(addr);
            });
          } catch (e) {
            _meshService.addLog('PEERS CONNECT HANDLER ERROR: $e', LogLevel.debug);
          }
        }
      }
    } catch (e) {
      _meshService.addLog('PEERS HANDLER ERROR: $e', LogLevel.error);
    }
  }

  // ─── حلقة Discovery كل 15 ثانية ─────────────────
  void _startDiscoveryLoop() {
    _discoveryTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _discover(),
    );
    _discover(); // أول مرة فوراً
  }

  // ─── UDP Listener for APP_BEACONs ─────────────────
  void _startUdpListener() async {
    try {
      final bindAddress = InternetAddress.anyIPv4;
      _udpSocket = await RawDatagramSocket.bind(bindAddress, _udpPort);
      try {
        _udpSocket?.broadcastEnabled = true;
      } catch (e) {
        _meshService.addLog('UDP SOCKET broadcast enable failed: $e', LogLevel.debug);
      }
      _meshService.addLog('UDP LISTENER: bound on ${bindAddress.address}:$_udpPort', LogLevel.info);
      _udpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram == null) return;
          try {
            final payload = utf8.decode(datagram.data);
            final map = jsonDecode(payload) as Map<String, dynamic>;
            if (map['type'] == 'APP_BEACON') {
              final addr = datagram.address.address;
              final nodeId = map['nodeId'] as String?;
              _meshService.addLog('APP_BEACON from $addr (${nodeId ?? "unknown"})', LogLevel.debug);
              try {
                _meshService.markAppDevice(addr, hostName: nodeId);
                unawaited(_tryConnectToAppPeer(addr));
              } catch (e) {
                _meshService.addLog('APP_BEACON markAppDevice error: $e', LogLevel.debug);
              }
            }
          } catch (e) {
            _meshService.addLog('UDP LISTENER parse ERROR: $e', LogLevel.debug);
          }
        }
      });
      _meshService.addLog('UDP LISTENER: bound on :$_udpPort', LogLevel.info);
    } catch (e) {
      _meshService.addLog('UDP LISTEN ERROR: $e', LogLevel.error);
    }
  }

  // ─── Broadcast APP_BEACON every 15s to announce app presence ──
  void _startUdpBeaconLoop() {
    _udpBeaconTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _sendUdpBeacon();
    });
    // send one immediately
    _sendUdpBeacon();
  }

  Future<void> _sendUdpBeacon() async {
    try {
      final beacon = jsonEncode({
        'type': 'APP_BEACON',
        'nodeId': _meshService.myNodeId,
        'groupId': _meshService.myGroupId,
        'ip': _myIp,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final data = utf8.encode(beacon);
      final socket = _udpSocket;
      if (socket == null) {
        _meshService.addLog('UDP BEACON: socket unavailable', LogLevel.warning);
        return;
      }

      // Collect all active network interfaces with valid IPv4
      final interfaces = <String, String>{}; // name -> ipv4
      try {
        final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        for (final ni in ifaces) {
          final name = ni.name.toLowerCase();
          // Skip loopback, link-local, and dummy interfaces
          if (name.contains('lo') || name.contains('dummy') || name.contains('ifb')) continue;
          for (final addr in ni.addresses) {
            final a = addr.address;
            if (!a.startsWith('127.') && !a.startsWith('169.254.') && !a.startsWith('::')) {
              interfaces[name] = a;
              break;
            }
          }
        }
      } catch (e) {
        _meshService.addLog('UDP BEACON: interface list error: $e', LogLevel.debug);
      }

      if (interfaces.isEmpty) {
        _meshService.addLog('UDP BEACON: no active interfaces found', LogLevel.debug);
        return;
      }

      // Send beacon from each active interface to its subnet broadcast and also global broadcast.
      for (final entry in interfaces.entries) {
        final name = entry.key;
        final localIp = entry.value;
        final parts = localIp.split('.');
        if (parts.length != 4 || !parts.every((p) => int.tryParse(p) != null)) continue;

        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        try {
          socket.send(data, InternetAddress(subnetBroadcast), _udpPort);
          _meshService.addLog('UDP BEACON SENT from $name ($localIp) -> $subnetBroadcast', LogLevel.debug);
        } catch (e) {
          _meshService.addLog('UDP BEACON ERROR on $name: $e', LogLevel.debug);
        }
      }

      try {
        const globalBroadcast = '255.255.255.255';
        socket.send(data, InternetAddress(globalBroadcast), _udpPort);
        _meshService.addLog('UDP BEACON SENT (global) -> $globalBroadcast', LogLevel.debug);
      } catch (e) {
        _meshService.addLog('UDP BEACON ERROR (global): $e', LogLevel.debug);
      }
    } catch (e) {
      _meshService.addLog('UDP BEACON ERROR: $e', LogLevel.error);
    }
  }

  Future<bool> _isLocalAddress(String ip) async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final ni in ifaces) {
        for (final addr in ni.addresses) {
          if (addr.address == ip) {
            return true;
          }
        }
      }
    } catch (e) {
      _meshService.addLog('LOCAL ADDRESS CHECK ERROR: $e', LogLevel.debug);
    }
    return false;
  }

  Future<void> _tryConnectToAppPeer(String ip) async {
    if (!_useWifiFallback) return;
    if (ip.isEmpty) return;
    if (_clientSockets.containsKey(ip) || _ongoingConnects.contains(ip)) return;
    if (await _isLocalAddress(ip)) return;
    if (_isGroupOwner && _p2pIp.isNotEmpty) return;

    _meshService.addLog('WIFI FALLBACK: discovered app peer $ip, attempting TCP connect', LogLevel.info);
    await connectAsClient(ip);
  }

  Future<void> _discover() async {
    _meshService.addLog('WIFI DIRECT: Discovering...', LogLevel.info);
    try {
      await _p2p.discover();
    } catch (e) {
      _meshService.addLog('DISCOVERY ERROR: $e', LogLevel.error);
    }
  }

  // ─── حدث تغيير معلومات P2P ───────────────────────
  Future<void> _onP2PInfoChanged(WifiP2PInfo info) async {
    final isGO = info.isGroupOwner;
    _myIp = info.groupOwnerAddress.toString().replaceAll('/', '').trim();

    // Try to resolve the local P2P IPv4 interface independently when available.
    try {
      final platformP2pInfo = await P2pHelper.getP2pInfo();
      if (platformP2pInfo != null) {
        if (platformP2pInfo.localIp != null && platformP2pInfo.localIp!.isNotEmpty) {
          _p2pIp = platformP2pInfo.localIp!;
        }
        if (!isGO && _myIp.isEmpty && platformP2pInfo.groupOwnerAddress != null) {
          _myIp = platformP2pInfo.groupOwnerAddress!.trim();
        }
      }
    } catch (e) {
      _meshService.addLog('P2P INFO PLATFORM ERROR: $e', LogLevel.debug);
    }

    if (_p2pIp.isEmpty) {
      _p2pIp = await _findP2pIPv4();
    }
    if (isGO && _p2pIp.isEmpty && _myIp.isNotEmpty) {
      _p2pIp = _myIp;
    }
    _meshService.addLog(
      'WIFI DIRECT INFO: Group Owner? $isGO GO_IP=$_myIp P2P_IP=$_p2pIp',
      LogLevel.info,
    );

    if (isGO && !_isGroupOwner) {
      // ترقية لـ Group Owner
      _isGroupOwner = true;
      _meshService.setGroupOwnerStatus(true, ip: _myIp);
      _startClientTCPServer();
      _bridgeManager.startBridgeServer(port: bridgePort);
      _meshService.addLog(
        'AUTO-PROMOTED: Now Group Owner @ $_myIp',
        LogLevel.info,
      );
    } else if (!isGO && _isGroupOwner) {
      // تراجع عن GO
      _isGroupOwner = false;
      _meshService.setGroupOwnerStatus(false);
      _clientServer?.close();
      _clientServer = null;
    }

    if (!isGO && _myIp.isEmpty) {
      // لم يتصل بعد → ترقية ذاتية
      _selfPromoteToGO();
    }
    // If this device is a client and we know the GO IP, try to connect via TCP
    if (!isGO && _myIp.isNotEmpty) {
      try {
        // avoid duplicate client connections
        if (!_clientSockets.containsKey(_myIp)) {
          _meshService.addLog('CLIENT: attempting TCP connect to GO $_myIp', LogLevel.info);
          await connectAsClient(_myIp);
        }
      } catch (e) {
        _meshService.addLog('CLIENT TCP CONNECT ERROR: $e', LogLevel.error);
      }
    }
  }

  // ─── ترقية ذاتية لـ Group Owner ──────────────────
  void _selfPromoteToGO() async {
    _meshService.addLog(
      'AUTO-PROMOTED: No network found, becoming Group Owner',
      LogLevel.info,
    );
    try {
      await _p2p.createGroup();
    } catch (e) {
      _meshService.addLog('CREATE GROUP ERROR: $e', LogLevel.error);
    }
  }


  // ─── TCP Server للـ Clients ───────────────────────
  Future<void> _startClientTCPServer() async {
    try {
      if (_clientServer != null) {
        _meshService.addLog('TCP SERVER: already running, skipping bind', LogLevel.debug);
        return;
      }
      // If wifi-fallback is enabled and we detected a wlan IP, bind to that
      // address. Otherwise bind to any IPv4 (normal Wi‑Fi Direct GO behavior).
      if (_useWifiFallback && _wlanIp.isNotEmpty) {
        final addr = InternetAddress(_wlanIp);
        _clientServer = await ServerSocket.bind(
          addr,
          clientPort,
        );
        _meshService.addLog('TCP SERVER: Listening on ${addr.address}:$clientPort (wlan-fallback)', LogLevel.info);
      } else {
        final bindIp = _p2pIp.isNotEmpty ? _p2pIp : '0.0.0.0';
        if (bindIp != '0.0.0.0') {
          final addr = InternetAddress(bindIp);
          _clientServer = await ServerSocket.bind(addr, clientPort);
          _meshService.addLog('TCP SERVER: Listening on ${addr.address}:$clientPort', LogLevel.info);
        } else {
          _clientServer = await ServerSocket.bind(InternetAddress.anyIPv4, clientPort);
          _meshService.addLog('TCP SERVER: Listening on :$clientPort', LogLevel.info);
        }
      }

      _clientServer!.listen((socket) {
        final clientIp = socket.remoteAddress.address;
        _clientSockets[clientIp] = socket;
        _clientLastActive[clientIp] = DateTime.now();
        _evictIfNeeded();
        _meshService.addLog(
          'NEW CLIENT CONNECTED: $clientIp',
          LogLevel.info,
        );

        // استقبال البيانات
        _handleIncomingSocket(socket);

        socket.done.then((_) {
          _clientSockets.remove(clientIp);
          _clientLastActive.remove(clientIp);
          _meshService.addLog(
            'CLIENT DISCONNECTED: $clientIp',
            LogLevel.warning,
          );
        });
      });
    } catch (e) {
      _meshService.addLog('TCP SERVER ERROR: $e', LogLevel.error);
    }
  }

  /// Try to detect the device's best local IPv4 address.
  /// Prefers Wi-Fi / swlan / p2p interfaces, then falls back to any available IPv4.
  Future<String> _getLocalIPv4() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final weighted = <Map<String, String>>[];
      final fallback = <String>[];
      for (final ni in ifaces) {
        final name = ni.name.toLowerCase();
        for (final addr in ni.addresses) {
          final a = addr.address;
          if (a.startsWith('127.') || a.startsWith('169.254.')) continue;
          if (name.contains('wlan') || name.contains('swlan') || name.contains('wifi') || name.contains('p2p')) {
            weighted.add({'name': name, 'ip': a});
          } else if (name.contains('rmnet') || name.contains('usb') || name.contains('dummy')) {
            continue;
          } else {
            fallback.add(a);
          }
        }
      }
      if (weighted.isNotEmpty) {
        return weighted.first['ip']!;
      }
      if (fallback.isNotEmpty) {
        return fallback.first;
      }
    } catch (e) {
      _meshService.addLog('LOCAL IP DETECT ERROR: $e', LogLevel.warning);
    }
    return '';
  }

  /// Try to find an IPv4 address that looks like a Wi‑Fi or Wi‑Fi Direct interface.
  Future<String> _findP2pIPv4() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final candidates = <Map<String, String>>[];
      for (final ni in ifaces) {
        final name = ni.name.toLowerCase();
        for (final addr in ni.addresses) {
          final a = addr.address;
          if (a.startsWith('127.') || a.startsWith('169.254.')) continue;
          if (name.contains('p2p')) {
            candidates.insert(0, {'name': name, 'ip': a});
          } else if (name.contains('wlan') || name.contains('swlan') || name.contains('wifi')) {
            candidates.add({'name': name, 'ip': a});
          }
        }
      }
      if (candidates.isNotEmpty) {
        return candidates.first['ip']!;
      }
    } catch (e) {
      _meshService.addLog('P2P IP DETECT ERROR: $e', LogLevel.warning);
    }
    return '';
  }

  // ─── اتصال كـ Client بالـ GO ──────────────────────
  Future<void> connectAsClient(String goIp) async {
    // Avoid duplicate active sockets
    if (_clientSockets.containsKey(goIp)) {
      _meshService.addLog('CLIENT: already connected to $goIp, skipping', LogLevel.debug);
      return;
    }

    // prevent concurrent connect storms
    if (_ongoingConnects.contains(goIp)) {
      _meshService.addLog('CLIENT: connect to $goIp already in progress', LogLevel.debug);
      return;
    }

    _ongoingConnects.add(goIp);
    try {
      const int maxAttempts = 3;
      Duration delay = const Duration(milliseconds: 250);
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          _meshService.addLog('CLIENT: attempting TCP connect to $goIp (attempt $attempt)', LogLevel.info);
          final socket = await Socket.connect(
            goIp,
            clientPort,
            timeout: const Duration(seconds: 8),
          );

          _clientSockets[goIp] = socket;
          _clientLastActive[goIp] = DateTime.now();
          try {
            _meshService.addLog('CLIENT SOCKET: connected to ${socket.remoteAddress.address}:${socket.remotePort} from ${socket.address.address}:${socket.port}', LogLevel.info);
          } catch (_) {}
          _evictIfNeeded();
          _meshService.addLog('CONNECTED TO GO: $goIp:$clientPort', LogLevel.info);

          _handleIncomingSocket(socket);

          // flush stored queue to this socket
          await _queue.flushToSocket(socket);
          return;
        } catch (e) {
          _meshService.addLog('CLIENT CONNECT ERROR to $goIp (attempt $attempt): $e', LogLevel.warning);
          if (attempt < maxAttempts) {
            await Future.delayed(delay);
            delay *= 2;
            continue;
          } else {
            _meshService.addLog('CLIENT: failed to connect to $goIp after $maxAttempts attempts', LogLevel.error);
          }
        }
      }
    } finally {
      _ongoingConnects.remove(goIp);
    }
  }

  // ─── معالجة Socket واردة ─────────────────────────
  void _handleIncomingSocket(Socket socket) {
    try {
      final ip = socket.remoteAddress.address;
      _meshService.addLog('SOCKET: starting listener for $ip', LogLevel.debug);
    } catch (_) {}
    // Use stream transformers to split incoming data by lines and avoid
    // unbounded StringBuffer growth. Also limit max acceptable line size.
    const int maxLineSize = 64 * 1024; // 64 KB

    socket
      .map((data) => utf8.decode(data, allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;

      // brief debug of incoming payload (truncate)
      try {
        final preview = trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
        _meshService.addLog('SOCKET RECV from ${socket.remoteAddress.address}: $preview', LogLevel.debug);
      } catch (_) {}

      try {
        // update last active time for this socket
        final ip = socket.remoteAddress.address;
        _clientLastActive[ip] = DateTime.now();
      } catch (_) {}

      if (trimmed.length > maxLineSize) {
        _meshService.addLog(
          'SOCKET LINE TOO LARGE from ${socket.remoteAddress.address}, closing',
          LogLevel.warning,
        );
        socket.destroy();
        return;
      }

      try {
        _processRawMessage(trimmed, socket);
      } catch (e, st) {
        _meshService.addLog('PROCESS RAW MESSAGE ERROR: $e\n$st', LogLevel.error);
      }
    }, onError: (e) {
      _meshService.addLog('SOCKET ERROR: $e', LogLevel.error);
    }, onDone: () {
      socket.destroy();
    });
  }

  void _evictIfNeeded() {
    if (_clientSockets.length <= _maxClients) return;
    final keys = _clientSockets.keys.toList();
    while (_clientSockets.length > _maxClients) {
      final oldest = keys.removeAt(0);
      final s = _clientSockets.remove(oldest);
      try {
        s?.destroy();
      } catch (_) {}
      _clientLastActive.remove(oldest);
      _meshService.addLog('EVICTED CLIENT: $oldest (maxClients) ', LogLevel.warning);
    }
  }

  void _startSocketCleanupTimer() {
    _socketCleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final now = DateTime.now();
      final stale = _clientLastActive.entries
          .where((e) => now.difference(e.value).inSeconds > 120)
          .map((e) => e.key)
          .toList();
      for (final ip in stale) {
        final s = _clientSockets.remove(ip);
        try { s?.destroy(); } catch (_) {}
        _clientLastActive.remove(ip);
        _meshService.addLog('CLEANUP: closed stale socket $ip', LogLevel.info);
      }
    });
  }

  // ─── معالجة رسالة خام ────────────────────────────
  void _processRawMessage(String raw, Socket sourceSocket) {
    _processRawMessageAsync(raw, sourceSocket);
  }

Future<void> _processRawMessageAsync(String raw, Socket sourceSocket) async {
  // GO_BEACON? handle directly without isolate for speed
  if (raw.contains('"type":"GO_BEACON"') || raw.contains('"type": "GO_BEACON"')) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final group = GroupInfo.fromJson(map);
      final previousTs = _seenGoBeaconTimestamps[group.groupId] ?? 0;
      final shouldForward = group.lastBeaconTimestamp > previousTs;
      _seenGoBeaconTimestamps[group.groupId] = group.lastBeaconTimestamp;

      _meshService.updateGroup(group);
      _bridgeManager.connectToBridge(group);

      if (shouldForward) {
        _meshService.addLog('GO_BEACON FORWARDING: ${group.groupId}', LogLevel.debug);
        _sendRawToPeers(raw, excluding: sourceSocket);
      } else {
        _meshService.addLog('GO_BEACON SKIP FORWARD: stale ${group.groupId}', LogLevel.debug);
      }
    } catch (e) {
      _meshService.addLog('GO_BEACON PARSE ERROR: $e', LogLevel.error);
    }
    return;
  }

    try {
    // enqueue for batched JSON parsing to reduce compute() churn
    final sourceIp = sourceSocket.remoteAddress.address;
    // call instance method on the service instance via global mapping
    // the instance methods will be invoked from where the service created the socket
    _enqueueJson(raw, sourceIp);
  } catch (e, st) {
    _meshService.addLog('PROCESS RAW MESSAGE ERROR (isolate): $e\n$st', LogLevel.error);
  }
}

// Top-level batch worker for JSON decode — must be a top-level function for compute()
List<Map<String, dynamic>> _jsonDecodeBatchWorker(List<String> raws) {
  final out = <Map<String, dynamic>>[];
  for (final r in raws) {
    try {
      out.add(jsonDecode(r) as Map<String, dynamic>);
    } catch (_) {
      out.add(<String, dynamic>{});
    }
  }
  return out;
}

  void _enqueueJson(String raw, String sourceIp) {
    _jsonQueue.add({'raw': raw, 'sourceIp': sourceIp});
    _jsonFlushTimer ??= Timer(_jsonFlushInterval, _flushJsonQueue);
  }

  Future<void> _flushJsonQueue() async {
    final batch = List<Map<String, String>>.from(_jsonQueue);
    _jsonQueue.clear();
    _jsonFlushTimer?.cancel();
    _jsonFlushTimer = null;
    if (batch.isEmpty) return;

    final raws = batch.map((e) => e['raw'] ?? '').toList();
    List<Map<String, dynamic>> maps = [];
    try {
      maps = await compute(_jsonDecodeBatchWorker, raws);
    } catch (e, st) {
      _meshService.addLog('BATCH JSON DECODE ERROR: $e\n$st', LogLevel.error);
      for (final r in raws) {
        try {
          maps.add(jsonDecode(r) as Map<String, dynamic>);
        } catch (_) {
          maps.add(<String, dynamic>{});
        }
      }
    }

    for (var i = 0; i < maps.length; i++) {
      final map = maps[i];
      final pending = batch[i];
      if (map.isEmpty) continue;
      try {
        final result = _meshService.processIncomingFromMap(map);
        if (result.decision == RoutingDecision.forward || result.decision == RoutingDecision.deliver) {
          if (result.processedMessage != null) {
            final excludingIp = pending['sourceIp'];
            final excluding = excludingIp != null ? _clientSockets[excludingIp] : null;
            _forwardMessage(result.processedMessage!, excluding: excluding);
          }
        }
      } catch (e, st) {
        _meshService.addLog('PROCESS BATCHED MAP ERROR: $e\n$st', LogLevel.error);
      }
    }
  }
// NOTE: helper methods for batching are implemented as static-ish functions
// where possible. The actual flush is handled by the instance method below.

  // ─── إرسال رسالة خام لكل الأقران ──────────────────
  Future<void> broadcastRaw(String raw) async {
    _meshService.addLog('BROADCAST RAW: sending to ${_clientSockets.length} peer socket(s)', LogLevel.debug);
    _sendRawToPeers(raw);
  }

  void _boundBridgeRaw(String raw) {
    if (_isGroupOwner) {
      _bridgeManager.broadcastRaw(raw);
    }
  }

  void _sendRawToPeers(String raw, {Socket? excluding}) {
    final bytes = utf8.encode('$raw\n');
    final failed = <String>[];

    for (final entry in _clientSockets.entries) {
      if (entry.value == excluding) continue;
      try {
        entry.value.add(bytes);
      } catch (e) {
        _meshService.addLog('RAW SEND ERROR to ${entry.key}: $e', LogLevel.error);
        failed.add(entry.key);
      }
    }

    for (final ip in failed) {
      _clientSockets.remove(ip);
      _clientLastActive.remove(ip);
    }

    _boundBridgeRaw(raw);
  }
  Future<void> broadcastMessage(MeshMessage message) async {
    final raw = '${message.toJsonString()}\n';
    final bytes = utf8.encode(raw);

    _meshService.addLog('BROADCAST: preparing to send to ${_clientSockets.length} client(s)', LogLevel.debug);

    // If there are no client sockets and we are a client (not GO), try connecting to GO
    if (_clientSockets.isEmpty && !_isGroupOwner && _myIp.isNotEmpty) {
      _meshService.addLog('BROADCAST: no client sockets — attempting connect to GO $_myIp before sending', LogLevel.info);
      try {
        // enqueue the message so it will be flushed after connect
        _queue.enqueue(message);
        await connectAsClient(_myIp);
        // if connected, flushQueue will be executed by connectAsClient
      } catch (e) {
        _meshService.addLog('BROADCAST: connect attempt failed: $e', LogLevel.warning);
      }
      return; // message queued — don't try immediate send now
    }

    final failed = <String>[];

    // Throttle writes in batches to avoid overwhelming OS buffers and device CPU.
    const int batchSize = 8;
    final List<Future> flushFutures = [];
    int i = 0;

    for (final entry in _clientSockets.entries) {
      try {
        entry.value.add(bytes);
        // schedule flush
        flushFutures.add(entry.value.flush());
      } catch (e) {
        _meshService.addLog('BROADCAST ERROR to ${entry.key}: $e', LogLevel.error);
        failed.add(entry.key);
        _queue.enqueue(message);
      }

      i++;
      if (i % batchSize == 0) {
        try {
          await Future.wait(flushFutures);
        } catch (_) {}
        flushFutures.clear();
        // short pause to yield CPU
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    // flush remaining
    if (flushFutures.isNotEmpty) {
      try {
        await Future.wait(flushFutures);
      } catch (_) {}
    }

    // أزل الـ Sockets المعطوبة
    for (final ip in failed) {
      _clientSockets.remove(ip);
    }

    _meshService.addLog('BROADCAST: completed, failed to send to ${failed.length} client(s)', LogLevel.debug);

    // أرسل للـ Bridges أيضاً (إذا أنا GO)
    if (_isGroupOwner) {
      _bridgeManager.broadcastToBridges(message);
    }
  }

  // ─── إعادة إرسال لكل إلا المصدر ─────────────────
  void _forwardMessage(MeshMessage message, {Socket? excluding}) {
    final raw = '${message.toJsonString()}\n';
    final bytes = utf8.encode(raw);

    for (final entry in _clientSockets.entries) {
      if (entry.value != excluding) {
        try {
          entry.value.add(bytes);
        } catch (_) {
          _queue.enqueue(message);
        }
      }
    }

    if (_isGroupOwner) {
      _bridgeManager.broadcastToBridges(message);
    }
  }

  // ─── Beacon كل 15 ثانية ──────────────────────────
  void _startBeaconLoop() {
    _beaconTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        final beacon = _meshService.createBeacon();
        broadcastMessage(beacon);
        _meshService.addLog(
          'BEACON SENT: Battery:${_meshService.myBattery}%',
          LogLevel.debug,
        );
      },
    );
  }

  // ─── Setters ──────────────────────────────────────
  void setMeshService(MeshService service) => _meshService = service;
  void setQueue(StoreForwardQueue queue) => _queue = queue;
  void setBridgeManager(BridgeManager manager) => _bridgeManager = manager;

  // ─── الصلاحيات ───────────────────────────────────
  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.microphone,
    ];

    for (final p in permissions) {
      final status = await p.request();
      _meshService.addLog(
        'PERMISSION ${p.toString()}: ${status.name}',
        LogLevel.info,
      );
    }
  }

  // ─── إيقاف الخدمة ────────────────────────────────
  Future<void> stop() async {
    _discoveryTimer?.cancel();
    _beaconTimer?.cancel();
    _udpBeaconTimer?.cancel();
    try { _udpSocket?.close(); } catch (_) {}
    _socketCleanupTimer?.cancel();
    _clientServer?.close();
    for (final s in _clientSockets.values) {
      s.destroy();
    }
    _clientSockets.clear();
    _clientLastActive.clear();
    await _p2p.unregister();
    _isRunning = false;
  }
}
