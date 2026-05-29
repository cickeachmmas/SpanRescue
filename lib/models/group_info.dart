// ═══════════════════════════════════════════════════════
// group_info.dart — معلومات مجموعة Wi-Fi Direct
// ═══════════════════════════════════════════════════════

class GroupInfo {
  final String groupId;
  final String goNodeId;       // معرّف Group Owner
  final String goIpAddress;    // IP لفتح Bridge TCP
  final int bridgePort;        // منفذ البريدج (8889)
  final int memberCount;
  final double lat;
  final double lng;
  final int lastBeaconTimestamp;

  const GroupInfo({
    required this.groupId,
    required this.goNodeId,
    required this.goIpAddress,
    required this.bridgePort,
    required this.memberCount,
    required this.lat,
    required this.lng,
    required this.lastBeaconTimestamp,
  });

  bool get isActive {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastBeaconTimestamp) < 45000;
  }

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      groupId: json['groupId'] as String,
      goNodeId: json['goNodeId'] as String,
      goIpAddress: json['goIP'] as String? ?? '192.168.49.1',
      bridgePort: json['bridgePort'] as int? ?? 8889,
      memberCount: json['memberCount'] as int? ?? 1,
      lat: (json['location']?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['location']?['lng'] as num?)?.toDouble() ?? 0.0,
      lastBeaconTimestamp: json['timestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'GO_BEACON',
    'groupId': groupId,
    'goNodeId': goNodeId,
    'goIP': goIpAddress,
    'bridgePort': bridgePort,
    'memberCount': memberCount,
    'location': {'lat': lat, 'lng': lng},
    'timestamp': lastBeaconTimestamp,
  };
}

// ═══════════════════════════════════════════════════════
// bridge_connection.dart — اتصال TCP بين مجموعتين
// ═══════════════════════════════════════════════════════

enum BridgeStatus {
  connecting,
  connected,
  disconnected,
  retrying,
}

class BridgeConnection {
  final String localGroupId;
  final String remoteGroupId;
  final String remoteGoNodeId;
  final String remoteIpAddress;
  final int remotePort;
  BridgeStatus status;
  int retryCount;
  int lastConnectedTimestamp;
  int messagesSent;
  int messagesReceived;

  BridgeConnection({
    required this.localGroupId,
    required this.remoteGroupId,
    required this.remoteGoNodeId,
    required this.remoteIpAddress,
    required this.remotePort,
    this.status = BridgeStatus.connecting,
    this.retryCount = 0,
    int? lastConnectedTimestamp,
    this.messagesSent = 0,
    this.messagesReceived = 0,
  }) : lastConnectedTimestamp =
           lastConnectedTimestamp ??
           DateTime.now().millisecondsSinceEpoch;

  bool get isConnected => status == BridgeStatus.connected;

  String get statusText {
    switch (status) {
      case BridgeStatus.connecting: return 'جاري الاتصال...';
      case BridgeStatus.connected: return 'متصل';
      case BridgeStatus.disconnected: return 'منقطع';
      case BridgeStatus.retrying:
        return 'إعادة المحاولة ($retryCount)';
    }
  }

  // وصف للـ Logs
  String get logDescription =>
      'BRIDGE $localGroupId ↔ $remoteGroupId @ $remoteIpAddress:$remotePort';
}
