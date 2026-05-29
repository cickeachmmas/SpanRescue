// ═══════════════════════════════════════════════════════
// mesh_service.dart — مدير الحالة المركزي
// يربط كل مكونات النظام معاً
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/mesh_message.dart';
import '../models/node_info.dart';
import '../models/group_info.dart';
import 'mesh_router.dart';
import 'geo_utils.dart';
import 'network_scanner.dart';

class MeshService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final MeshRouter _router = MeshRouter();
  final _uuid = const Uuid();
  final NetworkScanner _networkScanner = NetworkScanner();
  Timer? _scanTimer;

  // ─── معلومات الجهاز الحالي ───────────────────────
  late String myNodeId;
  late String myGroupId;
  bool isGroupOwner = false;
  String myIpAddress = '';
  NodeRole myRole = NodeRole.rescuer;
  TriageState myTriageState = TriageState.none;
  GeoLocation myLocation = const GeoLocation(lat: 0.0, lng: 0.0);
  int myBattery = 100;

  // ─── حالة الشبكة ─────────────────────────────────
  bool isMeshActive = false;
  final Map<String, NodeInfo> connectedNodes = {};
  final Map<String, GroupInfo> knownGroups = {};
  String? _simulatedLocalGroupId;
  final Set<String> _simulatedNodeIds = {};
  final List<NetworkDevice> _simulatedDevices = [];
  final List<NetworkDevice> _discoveredDevices = [];
  Timer? _simulationTimer;
  bool isScanning = false;

  bool get simulationActive => _simulatedNodeIds.isNotEmpty;
  int get simulationNodeCount => _simulatedNodeIds.length;
  List<String> get simulationNodeIds => List.unmodifiable(_simulatedNodeIds);
  String? get firstSimulatedNodeId => _simulatedNodeIds.isEmpty ? null : _simulatedNodeIds.first;
  String? get simulatedLocalGroupId => _simulatedLocalGroupId;
  int get simulatedAppDeviceCount => _simulatedDevices.where((d) => d.type == DeviceType.appActive).length;
  int get simulatedWifiDeviceCount => _simulatedDevices.where((d) => d.type == DeviceType.wifiOnly).length;
  int get simulatedNetworkDeviceCount => _simulatedDevices.length;
  List<NetworkDevice> get simulatedNetworkDevices => List.unmodifiable(_simulatedDevices);
  List<NetworkDevice> get discoveredDevices => List.unmodifiable([..._discoveredDevices, ..._simulatedDevices]);

  // ─── الرسائل ─────────────────────────────────────
  final List<MeshMessage> chatMessages = [];
  final List<MeshMessage> sosMessages = [];
  int unreadCount = 0;
  List<String> quickReplies = [];
  final Map<String, DateTime> typingIndicators = {}; // nodeId -> lastTypingTime

  // ─── السجلات ─────────────────────────────────────
  final List<LogEntry> systemLogs = [];

  // ─── Streams للاستماع ─────────────────────────────
  final StreamController<MeshMessage> _messageStream =
      StreamController<MeshMessage>.broadcast();
  final StreamController<MeshMessage> _sosStream =
      StreamController<MeshMessage>.broadcast();

  Stream<MeshMessage> get onMessage => _messageStream.stream;
  Stream<MeshMessage> get onSOS => _sosStream.stream;

  MeshService(this._prefs) {
    myNodeId = _prefs.getString('nodeId') ?? 'Node_000000';
    myGroupId = 'GRP_${myNodeId.replaceAll('Node_', '')}';
    _loadSavedMessages();
    _loadQuickReplies();
  }

  // ─── تهيئة ───────────────────────────────────────
  Future<void> initialize() async {
    addLog('START WIFI DIRECT NETWORK', LogLevel.info);
    myRole = NodeRole.values[_prefs.getInt('myRole') ?? 0];
    isMeshActive = true;

    // تنظيف دوري كل 5 دقائق
    Timer.periodic(const Duration(minutes: 5), (_) {
      _router.cleanupSeenBroadcasts();
      _removeOfflineNodes();
    });

    notifyListeners();
  }

  void refreshNetwork() {
    notifyListeners();
  }

  void toggleSimulation({int nodeCount = 8}) {
    if (simulationActive) {
      stopSimulation();
    } else {
      startSimulation(nodeCount: nodeCount);
    }
  }

  void startSimulation({int nodeCount = 8}) {
    stopSimulation();

    final now = DateTime.now().millisecondsSinceEpoch;
    final baseLat = myLocation.lat != 0.0 ? myLocation.lat : 35.3034;
    final baseLng = myLocation.lng != 0.0 ? myLocation.lng : 4.1754;
    // Create multiple simulated groups to mirror bridge topology
    final groupCount = math.min(4, (nodeCount / 5).ceil());
    final nodesPerGroup = (nodeCount / groupCount).ceil();

    int idx = 0;
    _simulatedLocalGroupId = 'GRP_SIM_1';
    for (int g = 1; g <= groupCount; g++) {
      final groupId = 'GRP_SIM_$g';
      // Assign a GO node id for this group (first node in the group)
      final goNodeId = 'SIM_${1000 + idx}';

      // Create nodes for this group
      for (int j = 0; j < nodesPerGroup && idx < nodeCount; j++, idx++) {
        final i = idx;
        final angle = (360 / nodeCount) * i;
        final distanceMeters = 60 + (i % 4) * 40;
        final loc = _offsetLocation(baseLat, baseLng, angle, distanceMeters.toDouble());
        final nodeId = 'SIM_${1000 + i}';
        final isGo = nodeId == goNodeId;
        final hop = isGo ? 1 : (i % 4) + 2;
        final discoveredVia = isGo ? myNodeId : goNodeId;

        final node = NodeInfo(
          nodeId: nodeId,
          groupId: groupId,
          role: i % 5 == 4 ? NodeRole.victim : NodeRole.rescuer,
          triageState: i % 7 == 0 ? TriageState.red : TriageState.green,
          medicalState: i % 9 == 0 ? MedicalState.red : MedicalState.none,
          location: loc,
          battery: 40 + (i * 5) % 60,
          lastSeenTimestamp: now,
          discoveredVia: discoveredVia,
          hopCount: hop,
          isGroupOwner: isGo,
          isBridgeNode: isGo, // mark GO as bridge-capable
          ipAddress: '192.168.49.${100 + i}',
        );

        connectedNodes[nodeId] = node;
        _simulatedNodeIds.add(nodeId);
      }

      // Add group info (GO beacon)
      final group = GroupInfo(
        groupId: groupId,
        goNodeId: goNodeId,
        goIpAddress: '192.168.49.${1 + g}',
        bridgePort: 8889,
        memberCount: nodesPerGroup + (g == 1 ? 1 : 0),
        lat: baseLat + 0.001 * g,
        lng: baseLng + 0.001 * g,
        lastBeaconTimestamp: now,
      );
      knownGroups[groupId] = group;
    }

    simulateNearbyDevices(appActiveCount: (nodeCount / 2).ceil(), wifiOnlyCount: 5);
    simulateGroupBeacon();
    _startSimulationLoop();

    addLog('SIMULATION STARTED: $nodeCount simulated nodes', LogLevel.info);
    notifyListeners();
  }

  void startFullSimulation({int nodeCount = 20}) {
    startSimulation(nodeCount: nodeCount);
    final starterId = firstSimulatedNodeId;
    if (starterId == null) return;

    Future.delayed(const Duration(seconds: 2), () {
      simulateTyping(starterId);
      addLog('SIMULATION EVENT: typing indicator activated', LogLevel.info);
    });

    Future.delayed(const Duration(seconds: 4), () {
      simulateIncomingChat(starterId, 'Test message from simulated node.');
    });

    Future.delayed(const Duration(seconds: 6), () {
      simulateIncomingVoice(starterId);
    });

    Future.delayed(const Duration(seconds: 9), () {
      simulateIncomingSOS(starterId);
    });

    Future.delayed(const Duration(seconds: 12), () {
      simulateNearbyDevices(appActiveCount: 8, wifiOnlyCount: 8);
    });

    Future.delayed(const Duration(seconds: 14), () {
      simulateGroupBeacon();
    });

    addLog('FULL SIMULATION SCENARIO STARTED', LogLevel.info);
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;

    for (final id in _simulatedNodeIds) {
      connectedNodes.remove(id);
    }

    final removedGroups = knownGroups.keys
        .where((id) => id.startsWith('GRP_SIM_'))
        .toList();
    for (final groupId in removedGroups) {
      knownGroups.remove(groupId);
    }

    _simulatedLocalGroupId = null;
    _simulatedNodeIds.clear();
    _simulatedDevices.clear();
    addLog('SIMULATION STOPPED', LogLevel.info);
    notifyListeners();
  }

  void simulateIncomingChat(String nodeId, String text) {
    final node = connectedNodes[nodeId];
    if (node == null) return;

    final message = MeshMessage(
      messageId: _uuid.v4(),
      senderId: node.nodeId,
      senderGroup: node.groupId,
      type: MessageType.chat,
      content: text,
      ttl: 10,
      hopCount: node.hopCount,
      seenBy: [node.groupId],
      path: [node.nodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: node.location,
      medicalState: node.medicalState,
      role: node.role,
      battery: node.battery,
      triageState: node.triageState,
    );

    processIncomingFromMap(message.toJson());
  }

  void simulateIncomingSOS(String nodeId) {
    final node = connectedNodes[nodeId];
    if (node == null) return;

    final message = MeshMessage(
      messageId: _uuid.v4(),
      senderId: node.nodeId,
      senderGroup: node.groupId,
      type: MessageType.sos,
      content: 'SIMULATED SOS from ${node.nodeId}',
      ttl: 99,
      hopCount: node.hopCount,
      seenBy: [node.groupId],
      path: [node.nodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: node.location,
      medicalState: MedicalState.red,
      role: node.role,
      battery: node.battery,
      triageState: TriageState.red,
    );

    processIncomingFromMap(message.toJson());
  }

  void simulateIncomingVoice(String nodeId) {
    final node = connectedNodes[nodeId];
    if (node == null) return;

    final message = MeshMessage(
      messageId: _uuid.v4(),
      senderId: node.nodeId,
      senderGroup: node.groupId,
      type: MessageType.voice,
      content: 'U2ltdWxhdGVkIGF1ZGlvIQ==',
      audioEof: '<EOF>',
      ttl: 10,
      hopCount: node.hopCount,
      seenBy: [node.groupId],
      path: [node.nodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: node.location,
      medicalState: node.medicalState,
      role: node.role,
      battery: node.battery,
      triageState: node.triageState,
    );

    processIncomingFromMap(message.toJson());
  }

  void simulateTyping(String nodeId) {
    if (!connectedNodes.containsKey(nodeId)) return;
    setTyping(nodeId);
    addLog('SIMULATION TYPING: $nodeId', LogLevel.info);
  }

  void simulateLogEntry(String message, LogLevel level) {
    addLog('SIMULATION LOG: $message', level);
  }

  void simulateNearbyDevices({int appActiveCount = 3, int wifiOnlyCount = 4}) {
    _simulatedDevices.clear();
    final baseIp = 200;
    for (int i = 0; i < appActiveCount; i++) {
      _simulatedDevices.add(NetworkDevice(
        ipAddress: '192.168.49.${baseIp + i}',
        hostName: 'SIM_APP_${i + 1}',
        type: DeviceType.appActive,
        isReachable: true,
        port: 8888,
      ));
    }
    for (int i = 0; i < wifiOnlyCount; i++) {
      _simulatedDevices.add(NetworkDevice(
        ipAddress: '192.168.49.${baseIp + 10 + i}',
        hostName: 'SIM_WIFI_${i + 1}',
        type: DeviceType.wifiOnly,
        isReachable: true,
        port: 80,
      ));
    }
    addLog('SIMULATION NETWORK DEVICES: ${_simulatedDevices.length} discovered', LogLevel.info);
    notifyListeners();
  }

  void simulateGroupBeacon() {
    if (!simulationActive) {
      addLog('SIMULATION GROUP BEACON: no active simulation', LogLevel.warning);
      return;
    }

    // Refresh beacons for all simulated groups
    final now = DateTime.now().millisecondsSinceEpoch;
    final simGroups = knownGroups.keys.where((id) => id.startsWith('GRP_SIM_')).toList();
    for (final gid in simGroups) {
      final group = knownGroups[gid]!;
      knownGroups[gid] = GroupInfo(
        groupId: group.groupId,
        goNodeId: group.goNodeId,
        goIpAddress: group.goIpAddress,
        bridgePort: group.bridgePort,
        memberCount: group.memberCount,
        lat: group.lat + (math.Random().nextDouble() - 0.5) * 0.002,
        lng: group.lng + (math.Random().nextDouble() - 0.5) * 0.002,
        lastBeaconTimestamp: now,
      );
      addLog('SIMULATED GO_BEACON: ${group.groupId}', LogLevel.info);
    }

    // Simulate bridges between groups (log only in simulation)
    if (simGroups.length > 1) {
      for (int i = 0; i < simGroups.length; i++) {
        for (int j = i + 1; j < simGroups.length; j++) {
          addLog('SIMULATED BRIDGE: ${simGroups[i]} ↔ ${simGroups[j]}', LogLevel.debug);
        }
      }
    }

    if (_simulatedLocalGroupId != null) {
      addLog('SIMULATION LOCAL GROUP: $_simulatedLocalGroupId', LogLevel.debug);
    }

    notifyListeners();
  }

  void _startSimulationLoop() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _updateSimulationNodes();
      if (_simulatedDevices.isNotEmpty && math.Random().nextBool()) {
        simulateNearbyDevices(
          appActiveCount: simulatedAppDeviceCount,
          wifiOnlyCount: simulatedWifiDeviceCount,
        );
      }
    });
  }

  void _updateSimulationNodes() {
    if (_simulatedNodeIds.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final baseLat = myLocation.lat != 0.0 ? myLocation.lat : 35.3034;
    final baseLng = myLocation.lng != 0.0 ? myLocation.lng : 4.1754;
    final random = math.Random();

    for (final nodeId in _simulatedNodeIds) {
      final node = connectedNodes[nodeId];
      if (node == null) continue;
      final deltaBearing = random.nextInt(360);
      final deltaDistance = 15 + random.nextInt(30);
      final newLocation = _offsetLocation(baseLat, baseLng, deltaBearing.toDouble(), deltaDistance.toDouble());
      final newBattery = (node.battery - 1).clamp(5, 100);
      connectedNodes[nodeId] = node.copyWith(
        location: newLocation,
        battery: newBattery,
        lastSeenTimestamp: now,
      );
    }

    for (final group in knownGroups.values.where((g) => g.groupId.startsWith('GRP_SIM_')).toList()) {
      knownGroups[group.groupId] = GroupInfo(
        groupId: group.groupId,
        goNodeId: group.goNodeId,
        goIpAddress: group.goIpAddress,
        bridgePort: group.bridgePort,
        memberCount: group.memberCount,
        lat: baseLat + random.nextDouble() * 0.002 - 0.001,
        lng: baseLng + random.nextDouble() * 0.002 - 0.001,
        lastBeaconTimestamp: now,
      );
    }

    notifyListeners();
  }

  GeoLocation _offsetLocation(
    double lat,
    double lng,
    double bearingDegrees,
    double distanceMeters,
  ) {
    final rad = bearingDegrees * 3.141592653589793 / 180.0;
    final deltaLat = distanceMeters / 111000.0 * math.cos(rad);
    final deltaLng = distanceMeters /
        (111000.0 * math.cos(lat * 3.141592653589793 / 180.0)) *
        math.sin(rad);
    return GeoLocation(lat: lat + deltaLat, lng: lng + deltaLng);
  }

  // ─── معالجة رسالة واردة ──────────────────────────
  RoutingResult processIncoming(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final message = MeshMessage.fromJson(map);

      final result = _router.processMessage(
        message,
        myNodeId: myNodeId,
        myGroupId: myGroupId,
      );

      addLog(result.reason, LogLevel.debug);

      if (result.decision == RoutingDecision.drop) {
        return result;
      }

      // beacon → تحديث معلومات العقدة
      if (message.isBeacon) {
        _handleBeacon(message);
        return result;
      }

      // SOS → تنبيه فوري
      if (message.isSOS) {
        _handleSOS(message);
      }

      // إذا كانت رسالة خاصة بي وصلت من الشبكة كنسخة مع seenBy أطول
      if (result.decision == RoutingDecision.deliverOnly &&
          message.senderId == myNodeId &&
          result.processedMessage != null) {
        _updateLocalMessageSeenBy(result.processedMessage!);
      }

      // رسائل Chat و Voice → أضف للشاشة
      if (message.isChat || message.isVoice || message.isSOS) {
        if (result.decision == RoutingDecision.deliver) {
          chatMessages.insert(0, message);
          unreadCount++;
          _messageStream.add(message);
          _saveMessages();
          notifyListeners();
        }
      }

      return result;
    } catch (e) {
      addLog('PARSE ERROR: $e', LogLevel.error);
      return RoutingResult(
        decision: RoutingDecision.drop,
        reason: 'PARSE_ERROR: $e',
      );
    }
  }

  // Process an already-decoded JSON map (useful when decoding runs in an isolate)
  RoutingResult processIncomingFromMap(Map<String, dynamic> map) {
    try {
      final message = MeshMessage.fromJson(map);

      final result = _router.processMessage(
        message,
        myNodeId: myNodeId,
        myGroupId: myGroupId,
      );

      addLog(result.reason, LogLevel.debug);

      if (result.decision == RoutingDecision.drop) {
        return result;
      }

      // beacon → تحديث معلومات العقدة
      if (message.isBeacon) {
        _handleBeacon(message);
        return result;
      }

      // SOS → تنبيه فوري
      if (message.isSOS) {
        _handleSOS(message);
      }

      // إذا كانت رسالة خاصة بي وصلت من الشبكة كنسخة مع seenBy أطول
      if (result.decision == RoutingDecision.deliverOnly &&
          message.senderId == myNodeId &&
          result.processedMessage != null) {
        _updateLocalMessageSeenBy(result.processedMessage!);
      }

      // رسائل Chat و Voice → أضف للشاشة
      if (message.isChat || message.isVoice || message.isSOS) {
        if (result.decision == RoutingDecision.deliver) {
          chatMessages.insert(0, message);
          unreadCount++;
          _messageStream.add(message);
          _saveMessages();
          notifyListeners();
        }
      }

      return result;
    } catch (e) {
      addLog('PARSE ERROR: $e', LogLevel.error);
      return RoutingResult(
        decision: RoutingDecision.drop,
        reason: 'PARSE_ERROR: $e',
      );
    }
  }

  // ─── إرسال رسالة نصية ────────────────────────────
  MeshMessage createChatMessage(String text) {
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myNodeId,
      senderGroup: myGroupId,
      type: MessageType.chat,
      content: text,
      ttl: 10,
      hopCount: 0,
      seenBy: [myGroupId],
      path: [myNodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: myLocation,
      medicalState: MedicalState.none,
      role: myRole,
      battery: myBattery,
      triageState: myTriageState,
    );

    // أضف للشاشة محلياً فوراً
    chatMessages.insert(0, msg);
    _messageStream.add(msg);
    _saveMessages();
    notifyListeners();

    return msg;
  }

  // ─── إرسال رسالة صوتية ───────────────────────────
  MeshMessage createVoiceMessage(String base64Audio) {
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myNodeId,
      senderGroup: myGroupId,
      type: MessageType.voice,
      content: base64Audio,
      ttl: 10,
      hopCount: 0,
      seenBy: [myGroupId],
      path: [myNodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: myLocation,
      medicalState: MedicalState.none,
      role: myRole,
      battery: myBattery,
      triageState: myTriageState,
    );

    chatMessages.insert(0, msg);
    _messageStream.add(msg);
    _saveMessages();
    notifyListeners();

    return msg;
  }

  // ─── إنشاء رد على رسالة موجودة (replyTo) ─────────
  MeshMessage createReplyMessage(String replyToMessageId, String text) {
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myNodeId,
      senderGroup: myGroupId,
      type: MessageType.chat,
      content: text,
      replyTo: replyToMessageId,
      ttl: 10,
      hopCount: 0,
      seenBy: [myGroupId],
      path: [myNodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: myLocation,
      medicalState: MedicalState.none,
      role: myRole,
      battery: myBattery,
      triageState: myTriageState,
    );

    // أضفه محلياً فوراً
    chatMessages.insert(0, msg);
    _messageStream.add(msg);
    _saveMessages();
    notifyListeners();

    return msg;
  }

  // ─── إرسال SOS ───────────────────────────────────
  MeshMessage createSOSMessage() {
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myNodeId,
      senderGroup: myGroupId,
      type: MessageType.sos,
      content: 'EMERGENCY: I need help!',
      ttl: 99, // SOS لا ينتهي
      hopCount: 0,
      seenBy: [],
      path: [myNodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: myLocation,
      medicalState: MedicalState.red,
      role: myRole,
      battery: myBattery,
      triageState: TriageState.red,
    );

    chatMessages.insert(0, msg);
    sosMessages.insert(0, msg);
    _sosStream.add(msg);
    _messageStream.add(msg);
    _saveMessages();
    addLog('🔴 SOS SENT from $myNodeId', LogLevel.sos);
    notifyListeners();

    return msg;
  }

  // ─── إنشاء Beacon ────────────────────────────────
  MeshMessage createBeacon() {
    return MeshMessage(
      messageId: _uuid.v4(),
      senderId: myNodeId,
      senderGroup: myGroupId,
      type: MessageType.beacon,
      content: '',
      ttl: 3, // Beacon لا يذهب بعيداً
      hopCount: 0,
      seenBy: [myGroupId],
      path: [myNodeId],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: myLocation,
      medicalState: MedicalState.none,
      role: myRole,
      battery: myBattery,
      triageState: myTriageState,
    );
  }

  // ─── معالجة Beacon ───────────────────────────────
  void _handleBeacon(MeshMessage beacon) {
    final existing = connectedNodes[beacon.senderId];
    if (existing != null) {
      connectedNodes[beacon.senderId] = existing.updateFromBeacon(beacon);
    } else {
      connectedNodes[beacon.senderId] = NodeInfo.fromBeacon(beacon);
      addLog(
        'NEW NODE: ${beacon.senderId} | Battery:${beacon.battery}% | Role:${beacon.role.name.toUpperCase()}',
        LogLevel.info,
      );
    }
    _router.updateRoute(beacon.senderId, beacon.discoveredVia ?? beacon.senderId);
    notifyListeners();
  }

  // ─── معالجة SOS ──────────────────────────────────
  void _handleSOS(MeshMessage sos) {
    sosMessages.insert(0, sos);
    _sosStream.add(sos);
    addLog(
      '🔴 SOS RECEIVED from ${sos.senderId} @ ${sos.location}',
      LogLevel.sos,
    );
  }

  // ─── تحديث المجموعات ─────────────────────────────
  void updateGroup(GroupInfo group) {
    final isNew = !knownGroups.containsKey(group.groupId);
    knownGroups[group.groupId] = group;
    if (isNew) {
      addLog(
        'GO_BEACON HEARD: ${group.groupId} @ ${group.goIpAddress}:${group.bridgePort}',
        LogLevel.info,
      );
    }
    notifyListeners();
  }

  // ─── حذف العقد المنقطعة ───────────────────────────
  void _removeOfflineNodes() {
    final offline = connectedNodes.entries
        .where((e) => !e.value.isOnline)
        .map((e) => e.key)
        .toList();

    for (final nodeId in offline) {
      connectedNodes.remove(nodeId);
      _router.removeRoute(nodeId);
      addLog('NODE TIMEOUT: $nodeId marked OFFLINE (45s)', LogLevel.warning);
    }

    if (offline.isNotEmpty) notifyListeners();
  }

  // ─── تحديث موقعي ─────────────────────────────────
  void updateMyLocation(double lat, double lng) {
    myLocation = GeoLocation(lat: lat, lng: lng);
    notifyListeners();
  }

  // ─── تحديث بطاريتي ───────────────────────────────
  void updateMyBattery(int level) {
    myBattery = level;
    notifyListeners();
  }

  // ─── تحديث حالة GO ───────────────────────────────
  void setGroupOwnerStatus(bool isGO, {String ip = ''}) {
    isGroupOwner = isGO;
    myIpAddress = ip;
    addLog(
      isGO
          ? 'AUTO-PROMOTED: Now Group Owner @ $ip'
          : 'WIFI DIRECT INFO: Group Owner? false',
      LogLevel.info,
    );
    notifyListeners();
  }

  // ─── إضافة لوق ───────────────────────────────────
  void addLog(String message, LogLevel level) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );
    systemLogs.insert(0, entry);

    // احتفظ بآخر 500 لوق فقط
    if (systemLogs.length > 500) {
      systemLogs.removeRange(500, systemLogs.length);
    }

    // Also emit to debug output so `flutter logs` captures it during tests
    try {
      debugPrint('${entry.isoTimestamp} ${entry.prefix}${entry.message}');
    } catch (_) {}

    notifyListeners();
  }

  // ─── تحديد قراءة الرسائل ─────────────────────────
  void markAllRead() {
    unreadCount = 0;
    notifyListeners();
  }

  // ─── قوائم مفيدة للـ UI ──────────────────────────
  List<NodeInfo> get onlineNodes =>
      connectedNodes.values.where((n) => n.isOnline).toList();

  List<NodeInfo> get rescuers =>
      onlineNodes.where((n) => n.isRescuer).toList();

  List<NodeInfo> get victims =>
      onlineNodes.where((n) => n.isVictim).toList();

  // ─── حساب مسافة عقدة ─────────────────────────────
  double distanceTo(NodeInfo node) {
    if (myLocation.isGpsDenied) return 0.0;
    final loc = node.location.isGpsDenied
        ? GeoUtils.interpolatePosition(
            rescuerLocation: myLocation,
            victimNodeId: node.nodeId,
          )
        : node.location;

    return GeoUtils.distanceInMeters(
      myLocation.lat, myLocation.lng,
      loc.lat, loc.lng,
    );
  }

  // ─── حفظ وتحميل الرسائل ──────────────────────────
  void _saveMessages() {
    final last50 = chatMessages.take(50).map((m) => m.toJson()).toList();
    _prefs.setString('messages', jsonEncode(last50));
  }

  void _loadSavedMessages() {
    final saved = _prefs.getString('messages');
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List;
        chatMessages.addAll(
          list.map((m) => MeshMessage.fromJson(m as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
  }

  void _loadQuickReplies() {
    final saved = _prefs.getStringList('quickReplies');
    if (saved != null && saved.isNotEmpty) {
      quickReplies = saved;
    } else {
      quickReplies = [
        'I\'m coming',
        'Hold on',
        'Need ETA?',
      ];
    }
  }

  void _saveQuickReplies() {
    _prefs.setStringList('quickReplies', quickReplies);
  }

  void addQuickReply(String reply) {
    if (reply.trim().isEmpty) return;
    quickReplies.add(reply.trim());
    _saveQuickReplies();
    notifyListeners();
  }

  void updateQuickReply(int index, String reply) {
    if (index < 0 || index >= quickReplies.length) return;
    quickReplies[index] = reply.trim();
    _saveQuickReplies();
    notifyListeners();
  }

  void removeQuickReply(int index) {
    if (index < 0 || index >= quickReplies.length) return;
    quickReplies.removeAt(index);
    _saveQuickReplies();
    notifyListeners();
  }

  void _updateLocalMessageSeenBy(MeshMessage incoming) {
    final idx = chatMessages.indexWhere((m) => m.messageId == incoming.messageId);
    if (idx == -1) return;
    final current = chatMessages[idx];
    if (incoming.seenBy.length <= current.seenBy.length) return;

    chatMessages[idx] = current.copyWith(
      seenBy: incoming.seenBy,
      path: incoming.path,
    );
    _saveMessages();
    notifyListeners();
    addLog('MESSAGE UPDATED SEENBY: ${incoming.messageId}', LogLevel.debug);
  }

  // ─── حذف رسالة محلياً ───────────────────────────
  void deleteMessage(String messageId) {
    final idx = chatMessages.indexWhere((m) => m.messageId == messageId);
    if (idx == -1) return;
    final old = chatMessages[idx];
    final deleted = old.copyWith(deleted: true);
    chatMessages[idx] = deleted;
    _saveMessages();
    notifyListeners();
    addLog('MESSAGE DELETED: $messageId', LogLevel.info);
  }

  // ─── استعادة رسالة محذوفة (undo) ───────────────
  void restoreMessage(String messageId) {
    final idx = chatMessages.indexWhere((m) => m.messageId == messageId);
    if (idx == -1) return;
    final old = chatMessages[idx];
    final restored = old.copyWith(deleted: false);
    chatMessages[idx] = restored;
    _saveMessages();
    notifyListeners();
    addLog('MESSAGE RESTORED: $messageId', LogLevel.info);
  }

  // ─── تعديل محتوى رسالة أرسلتها محلياً ───────────
  bool editMessage(String messageId, String newContent) {
    final idx = chatMessages.indexWhere((m) => m.messageId == messageId);
    if (idx == -1) return false;
    final old = chatMessages[idx];
    if (old.senderId != myNodeId) return false; // لا تسمح بتعديل رسائل الآخرين

    final updated = old.copyWith(
      content: newContent,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      edited: true,
    );

    chatMessages[idx] = updated;
    _saveMessages();
    notifyListeners();
    addLog('MESSAGE EDITED: $messageId', LogLevel.info);
    return true;
  }

  // ─── إرسال إشارة كتابة ──────────────────────────
  void setTyping(String nodeId) {
    typingIndicators[nodeId] = DateTime.now();
    notifyListeners();
    // حذف الإشارة بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () {
      if (typingIndicators[nodeId]?.isBefore(DateTime.now().subtract(const Duration(milliseconds: 2800))) ?? false) {
        typingIndicators.remove(nodeId);
        notifyListeners();
      }
    });
  }

  // ─── الحصول على قائمة من يكتب الآن ───────────────
  List<String> getTypingUsers() {
    final now = DateTime.now();
    typingIndicators.removeWhere((_, time) => now.difference(time).inSeconds > 3);
    return typingIndicators.keys.where((nodeId) => nodeId != myNodeId).toList();
  }

  // ─── البدء بمسح الشبكة ──────────────────────────
  Future<void> startNetworkScan() async {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    // مسح أولي فوري
    await _performNetworkScan();

    // مسح دوري كل 60 ثانية (خفف الحمل)
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _performNetworkScan();
    });
  }

  // ─── تنفيذ المسح ──────────────────────────────
  Future<void> _performNetworkScan() async {
    try {
      _discoveredDevices.clear();
      _discoveredDevices.addAll(await _networkScanner.scanNetwork());
      addLog('NETWORK SCAN: Found ${_discoveredDevices.length} devices', LogLevel.info);
      notifyListeners();
    } catch (e) {
      addLog('NETWORK SCAN ERROR: $e', LogLevel.error);
    }
  }

  // ─── إيقاف المسح ──────────────────────────────
  void stopNetworkScan() {
    _scanTimer?.cancel();
    _discoveredDevices.clear();
    isScanning = false;
    notifyListeners();
  }

  // ─── الحصول على الأجهزة المتصلة بالتطبيق ───────
  List<NetworkDevice> getActiveAppDevices() {
    return discoveredDevices
        .where((d) => d.type == DeviceType.appActive)
        .toList();
  }

  // ─── الحصول على أجهزة الشبكة الأخرى ───────────
  List<NetworkDevice> getWifiOnlyDevices() {
    return discoveredDevices
        .where((d) => d.type == DeviceType.wifiOnly)
        .toList();
  }

  // ─── وسم جهاز بأنه يشغل التطبيق عند استقبال APP_BEACON عبر UDP ──
  void markAppDevice(String ip, {String? hostName}) {
    try {
      final existing = _discoveredDevices.indexWhere((d) => d.ipAddress == ip);
      final dev = NetworkDevice(
        ipAddress: ip,
        hostName: hostName,
        type: DeviceType.appActive,
        isReachable: true,
      );
      if (existing != -1) {
        _discoveredDevices[existing] = dev;
      } else {
        _discoveredDevices.add(dev);
      }
      notifyListeners();
      addLog('MARK APP DEVICE: $ip (${hostName ?? 'unknown'})', LogLevel.info);
    } catch (e) {
      addLog('MARK APP DEVICE ERROR: $e', LogLevel.error);
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _messageStream.close();
    _sosStream.close();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════
// LogEntry — سجل واحد للـ Logs screen
// ═══════════════════════════════════════════════════════
enum LogLevel { info, debug, warning, error, sos }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  const LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get isoTimestamp {
    return timestamp.toIso8601String().replaceFirst('T', 'T');
  }

  String get prefix {
    switch (level) {
      case LogLevel.info: return '';
      case LogLevel.debug: return '';
      case LogLevel.warning: return '⚠️ ';
      case LogLevel.error: return '❌ ';
      case LogLevel.sos: return '🔴 ';
    }
  }
}
