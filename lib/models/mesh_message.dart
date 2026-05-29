// ═══════════════════════════════════════════════════════
// mesh_message.dart — هيكل الرسالة الكامل
// كل رسالة في الشبكة تستخدم هذا الهيكل بدون استثناء
// ═══════════════════════════════════════════════════════

enum MessageType {
  chat,      // رسالة نصية عادية
  voice,     // رسالة صوتية
  sos,       // نداء استغاثة — يتجاوز كل البروتوكول
  beacon,    // نبضة حياة كل 15 ثانية
  beaconGo,  // نبضة Group Owner للـ Bridge
  rreq,      // reserved for future route-control messages
  rrep,      // reserved for future route-control messages
}

enum MedicalState { red, yellow, green, none }

enum NodeRole { rescuer, victim }

enum TriageState { red, yellow, green, none }

class GeoLocation {
  final double lat;
  final double lng;
  final bool isInterpolated; // true = GPS مفقود، وضع تقديري

  const GeoLocation({
    required this.lat,
    required this.lng,
    this.isInterpolated = false,
  });

  // GPS مفقود إذا كانت الإحداثيات صفر
  bool get isGpsDenied => lat == 0.0 && lng == 0.0;

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      isInterpolated: json['isInterpolated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'isInterpolated': isInterpolated,
  };

  @override
  String toString() => '($lat, $lng)';
}

class MeshMessage {
  // ─── معرّفات ───────────────────────────────────────
  final String messageId;      // UUID فريد — يمنع التكرار
  final String senderId;       // Node_XXXXXX
  final String senderGroup;    // GRP_XXXX

  // ─── المحتوى ──────────────────────────────────────
  final MessageType type;
  final String content;        // نص أو Base64 صوت
  final String? audioEof;      // علامة نهاية الصوت "<EOF>"
  final String? replyTo;      // messageId this message is replying to (optional)
  final bool edited;          // whether the message was edited
  final bool deleted;         // whether the message was deleted
  // ─── توجيه البث / metadata ────────────────────────────────
  final int ttl;               // Time To Live — يبدأ من 10
  final int hopCount;          // عدد القفزات المنجزة
  final List<String> seenBy;   // مجموعات رأت هذه الرسالة
  final List<String> path;     // مسار الرسالة للـ Topology
  final String? discoveredVia; // من عرّفني على هذا الجهاز

  // ─── معلومات المرسل ───────────────────────────────
  final int timestamp;
  final GeoLocation location;
  final MedicalState medicalState;
  final NodeRole role;
  final int battery;           // نسبة البطارية 0-100
  final TriageState triageState;

  const MeshMessage({
    required this.messageId,
    required this.senderId,
    required this.senderGroup,
    required this.type,
    required this.content,
    this.audioEof,
    this.replyTo,
    this.edited = false,
    this.deleted = false,
    required this.ttl,
    required this.hopCount,
    required this.seenBy,
    required this.path,
    this.discoveredVia,
    required this.timestamp,
    required this.location,
    required this.medicalState,
    required this.role,
    required this.battery,
    required this.triageState,
  });

  // ─── نسخة معدّلة للتوجيه ─────────────────────────
  MeshMessage copyWithHop({
    required String currentGroupId,
    required String currentNodeId,
  }) {
    return MeshMessage(
      messageId: messageId,
      senderId: senderId,
      senderGroup: senderGroup,
      type: type,
      content: content,
      audioEof: audioEof,
      replyTo: replyTo,
      edited: edited,
      deleted: deleted,
      ttl: ttl - 1,                          // نقّص TTL
      hopCount: hopCount + 1,                // زد hopCount
      seenBy: [...seenBy, currentGroupId],   // أضف المجموعة الحالية
      path: [...path, currentNodeId],        // أضف العقدة للمسار
      discoveredVia: discoveredVia,
      timestamp: timestamp,
      location: location,
      medicalState: medicalState,
      role: role,
      battery: battery,
      triageState: triageState,
    );
  }

  // ─── SOS لا يُنقص TTL ────────────────────────────
  MeshMessage copyForSOSForward({required String currentNodeId}) {
    return MeshMessage(
      messageId: messageId,
      senderId: senderId,
      senderGroup: senderGroup,
      type: type,
      content: content,
      audioEof: audioEof,
      replyTo: replyTo,
      edited: edited,
      deleted: deleted,
      ttl: 99,                               // SOS لا ينتهي أبداً
      hopCount: hopCount + 1,
      seenBy: seenBy,                        // SOS يتجاوز seenBy
      path: [...path, currentNodeId],
      discoveredVia: discoveredVia,
      timestamp: timestamp,
      location: location,
      medicalState: medicalState,
      role: role,
      battery: battery,
      triageState: triageState,
    );
  }

  // ─── JSON ─────────────────────────────────────────
  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      messageId: json['messageId'] as String,
      senderId: json['senderId'] as String,
      senderGroup: json['senderGroup'] as String? ?? 'GRP_000',
      type: _parseType(json['type'] as String?),
      content: json['content'] as String? ?? '',
      audioEof: json['audioEof'] as String?,
      replyTo: json['replyTo'] as String?,
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      ttl: json['ttl'] as int? ?? 10,
      hopCount: json['hopCount'] as int? ?? 0,
      seenBy: List<String>.from(json['seenBy'] as List? ?? []),
      path: List<String>.from(json['path'] as List? ?? []),
      discoveredVia: json['discoveredVia'] as String?,
      timestamp: json['timestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      location: GeoLocation.fromJson(
        json['location'] as Map<String, dynamic>? ?? {},
      ),
      medicalState: _parseMedical(json['medicalState'] as String?),
      role: _parseRole(json['role'] as String?),
      battery: json['battery'] as int? ?? 100,
      triageState: _parseTriage(json['triageState'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'senderId': senderId,
    'senderGroup': senderGroup,
    'type': type.name,
    'content': content,
    if (replyTo != null) 'replyTo': replyTo,
    if (edited) 'edited': edited,
    if (deleted) 'deleted': deleted,
    if (audioEof != null) 'audioEof': audioEof,
    'ttl': ttl,
    'hopCount': hopCount,
    'seenBy': seenBy,
    'path': path,
    if (discoveredVia != null) 'discoveredVia': discoveredVia,
    'timestamp': timestamp,
    'location': location.toJson(),
    'medicalState': medicalState.name,
    'role': role.name,
    'battery': battery,
    'triageState': triageState.name,
  };

  String toJsonString() {
    final buffer = StringBuffer('{');
    final map = toJson();
    var first = true;
    map.forEach((k, v) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$k":');
      if (v is String) {
        buffer.write('"${v.replaceAll('"', '\\"')}"');
      } else if (v is List) {
        buffer.write('[${v.map((e) => '"$e"').join(',')}]');
      } else if (v is Map) {
        buffer.write(_mapToJson(v));
      } else {
        buffer.write(v);
      }
    });
    buffer.write('}');
    return buffer.toString();
  }

  String _mapToJson(Map map) {
    final parts = map.entries.map((e) {
      final v = e.value;
      if (v is String) return '"${e.key}":"$v"';
      if (v is bool) return '"${e.key}":$v';
      return '"${e.key}":$v';
    });
    return '{${parts.join(',')}}';
  }

  // ─── Helpers ──────────────────────────────────────
  static MessageType _parseType(String? s) {
    switch (s) {
      case 'voice': return MessageType.voice;
      case 'sos': return MessageType.sos;
      case 'beacon': return MessageType.beacon;
      case 'beaconGo': return MessageType.beaconGo;
      case 'rreq': return MessageType.rreq;
      case 'rrep': return MessageType.rrep;
      default: return MessageType.chat;
    }
  }

  static MedicalState _parseMedical(String? s) {
    switch (s) {
      case 'red': return MedicalState.red;
      case 'yellow': return MedicalState.yellow;
      case 'green': return MedicalState.green;
      default: return MedicalState.none;
    }
  }

  static NodeRole _parseRole(String? s) {
    return s == 'victim' ? NodeRole.victim : NodeRole.rescuer;
  }

  static TriageState _parseTriage(String? s) {
    switch (s) {
      case 'red': return TriageState.red;
      case 'yellow': return TriageState.yellow;
      case 'green': return TriageState.green;
      default: return TriageState.none;
    }
  }

  bool get isSOS => type == MessageType.sos;
  bool get isVoice => type == MessageType.voice;
  bool get isBeacon =>
      type == MessageType.beacon || type == MessageType.beaconGo;
  bool get isChat => type == MessageType.chat;
  bool get isExpired => ttl <= 0;

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);

  // ─── Copy with modifications (used for editing messages) ─────────
  MeshMessage copyWith({
    String? content,
    int? timestamp,
    MessageType? type,
    String? audioEof,
    String? replyTo,
    bool? edited,
    bool? deleted,
    List<String>? seenBy,
    List<String>? path,
  }) {
    return MeshMessage(
      messageId: messageId,
      senderId: senderId,
      senderGroup: senderGroup,
      type: type ?? this.type,
      content: content ?? this.content,
      audioEof: audioEof ?? this.audioEof,
      replyTo: replyTo ?? this.replyTo,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      ttl: ttl,
      hopCount: hopCount,
      seenBy: seenBy ?? List<String>.from(this.seenBy),
      path: path ?? List<String>.from(this.path),
      discoveredVia: discoveredVia,
      timestamp: timestamp ?? this.timestamp,
      location: location,
      medicalState: medicalState,
      role: role,
      battery: battery,
      triageState: triageState,
    );
  }
}
