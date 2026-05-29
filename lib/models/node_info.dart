// ═══════════════════════════════════════════════════════
// node_info.dart — معلومات كل جهاز في الشبكة
// يُحدَّث عند كل beacon واردة
// ═══════════════════════════════════════════════════════

import 'mesh_message.dart';

class NodeInfo {
  final String nodeId;
  final String groupId;
  final NodeRole role;
  final TriageState triageState;
  final MedicalState medicalState;
  final GeoLocation location;
  final int battery;
  final int lastSeenTimestamp;
  final String? discoveredVia;  // AODV: من أين عرفت هذا الجهاز
  final int hopCount;           // عدد القفزات بيني وبينه
  final bool isGroupOwner;
  final bool isBridgeNode;
  final String? ipAddress;      // للاتصال المباشر إذا كان في نفس المجموعة

  const NodeInfo({
    required this.nodeId,
    required this.groupId,
    required this.role,
    required this.triageState,
    required this.medicalState,
    required this.location,
    required this.battery,
    required this.lastSeenTimestamp,
    this.discoveredVia,
    this.hopCount = 1,
    this.isGroupOwner = false,
    this.isBridgeNode = false,
    this.ipAddress,
  });

  // ─── هل الجهاز لا يزال متصلاً؟ ──────────────────
  // إذا لم يصلنا beacon منذ 45 ثانية → غير متصل
  bool get isOnline {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeenTimestamp) < 45000;
  }

  // ─── المسافة بالأمتار (تُحسب خارجياً) ───────────
  double distanceTo(GeoLocation myLocation) {
    // Haversine Formula — تُطبّق في GeoUtils
    return 0.0; // placeholder
  }

  // ─── ألوان الحالة للـ UI ──────────────────────────
  bool get isVictim => role == NodeRole.victim;
  bool get isRescuer => role == NodeRole.rescuer;
  bool get isCritical => triageState == TriageState.red ||
      medicalState == MedicalState.red;

  bool get isBridge => isBridgeNode;

  // ─── تحديث من beacon واردة ───────────────────────
  NodeInfo updateFromBeacon(MeshMessage beacon) {
    return NodeInfo(
      nodeId: nodeId,
      groupId: beacon.senderGroup,
      role: beacon.role,
      triageState: beacon.triageState,
      medicalState: beacon.medicalState,
      location: beacon.location,
      battery: beacon.battery,
      lastSeenTimestamp: beacon.timestamp,
      discoveredVia: discoveredVia,
      hopCount: hopCount,
      isGroupOwner: isGroupOwner,
      isBridgeNode: isBridgeNode,
      ipAddress: ipAddress,
    );
  }

  NodeInfo copyWith({
    String? groupId,
    NodeRole? role,
    TriageState? triageState,
    MedicalState? medicalState,
    GeoLocation? location,
    int? battery,
    int? lastSeenTimestamp,
    String? discoveredVia,
    int? hopCount,
    bool? isGroupOwner,
    bool? isBridgeNode,
    String? ipAddress,
  }) {
    return NodeInfo(
      nodeId: nodeId,
      groupId: groupId ?? this.groupId,
      role: role ?? this.role,
      triageState: triageState ?? this.triageState,
      medicalState: medicalState ?? this.medicalState,
      location: location ?? this.location,
      battery: battery ?? this.battery,
      lastSeenTimestamp: lastSeenTimestamp ?? this.lastSeenTimestamp,
      discoveredVia: discoveredVia ?? this.discoveredVia,
      hopCount: hopCount ?? this.hopCount,
      isGroupOwner: isGroupOwner ?? this.isGroupOwner,
      isBridgeNode: isBridgeNode ?? this.isBridgeNode,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }

  factory NodeInfo.fromBeacon(MeshMessage beacon) {
    return NodeInfo(
      nodeId: beacon.senderId,
      groupId: beacon.senderGroup,
      role: beacon.role,
      triageState: beacon.triageState,
      medicalState: beacon.medicalState,
      location: beacon.location,
      battery: beacon.battery,
      lastSeenTimestamp: beacon.timestamp,
      discoveredVia: beacon.discoveredVia,
      hopCount: beacon.hopCount,
      isBridgeNode: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'groupId': groupId,
    'role': role.name,
    'triageState': triageState.name,
    'medicalState': medicalState.name,
    'location': location.toJson(),
    'battery': battery,
    'lastSeenTimestamp': lastSeenTimestamp,
    'discoveredVia': discoveredVia,
    'hopCount': hopCount,
    'isGroupOwner': isGroupOwner,
      'isBridgeNode': isBridgeNode,
  };

  // نص المسافة للعرض
  String distanceText(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // نص وقت آخر ظهور
  String get lastSeenText {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastSeenTimestamp;
    if (diff < 15000) return 'الآن';
    if (diff < 60000) return '${(diff / 1000).round()}s ago';
    if (diff < 3600000) return '${(diff / 60000).round()}m ago';
    return 'غير متصل';
  }
}
