// ═══════════════════════════════════════════════════════
// mesh_router.dart — قلب التوجيه
// AODV-inspired routing على مستوى التطبيق
// seenBroadcasts يمنع Broadcast Storms
// ═══════════════════════════════════════════════════════

import '../models/mesh_message.dart';

enum RoutingDecision {
  forward,     // أعد الإرسال
  drop,        // تجاهل
  deliver,     // عرض للمستخدم وأعد الإرسال
  deliverOnly, // عرض فقط (أنا الهدف)
}

class RoutingResult {
  final RoutingDecision decision;
  final MeshMessage? processedMessage; // الرسالة بعد تعديل TTL وseenBy
  final String reason;

  const RoutingResult({
    required this.decision,
    this.processedMessage,
    required this.reason,
  });
}

class MeshRouter {
  // ─── seenBroadcasts — قلب منع التكرار ────────────
  // كل messageId شاهدناه نضيفه هنا فوراً
  final Set<String> _seenBroadcasts = {};

  // جدول التوجيه: nodeId → nextHop IP/nodeId
  final Map<String, String> _routingTable = {};

  // عدد الرسائل المعالجة (للـ Logs)
  int _totalProcessed = 0;
  int _totalDropped = 0;
  int _totalForwarded = 0;

  // ─── القرار الرئيسي ──────────────────────────────
  RoutingResult processMessage(
    MeshMessage message, {
    required String myNodeId,
    required String myGroupId,
  }) {
    _totalProcessed++;

    // ── SOS OVERRIDE: تجاوز كل القواعد ──────────────
    if (message.isSOS) {
      return _processSOS(message, myNodeId: myNodeId);
    }

    // ── Beacon: لا توجيه، فقط استخراج المعلومات ─────
    if (message.isBeacon) {
      return RoutingResult(
        decision: RoutingDecision.deliverOnly,
        processedMessage: message,
        reason: 'BEACON from ${message.senderId}',
      );
    }

    // ── القاعدة 1: هل رأينا هذه الرسالة قبل؟ ────────
    if (_seenBroadcasts.contains(message.messageId)) {
      _totalDropped++;
      return RoutingResult(
        decision: RoutingDecision.drop,
        reason: 'DUPLICATE: ${message.messageId}',
      );
    }

    // ── القاعدة 2: هل انتهى TTL؟ ─────────────────────
    if (message.isExpired) {
      _totalDropped++;
      return RoutingResult(
        decision: RoutingDecision.drop,
        reason: 'TTL_EXPIRED: hopCount=${message.hopCount}',
      );
    }

    // ── أضف للـ seenBroadcasts فوراً ─────────────────
    _seenBroadcasts.add(message.messageId);

    // ── نسخة معدّلة للتوجيه ──────────────────────────
    final forwarded = message.copyWithHop(
      currentGroupId: myGroupId,
      currentNodeId: myNodeId,
    );

    _totalForwarded++;

    // ── هل أنا مرسِل هذه الرسالة؟ ───────────────────
    if (message.senderId == myNodeId) {
      return RoutingResult(
        decision: RoutingDecision.deliverOnly,
        processedMessage: forwarded,
        reason: 'MY_OWN_MESSAGE',
      );
    }

    // ── رسالة جديدة من جهاز آخر → عرض وإعادة إرسال ──
    return RoutingResult(
      decision: RoutingDecision.deliver,
      processedMessage: forwarded,
      reason: 'FORWARD from ${message.senderId} TTL=${forwarded.ttl}',
    );
  }

  // ─── معالجة SOS ──────────────────────────────────
  RoutingResult _processSOS(MeshMessage sos, {required String myNodeId}) {
    // SOS يُعرض دائماً حتى لو رأيناه قبل
    // لكن نمنع الحلقة اللانهائية بعد 3 مرات
    final key = '${sos.messageId}_${sos.hopCount}';

    if (_seenBroadcasts.contains(key)) {
      return RoutingResult(
        decision: RoutingDecision.drop,
        reason: 'SOS_LOOP_PREVENTION: hop=${sos.hopCount}',
      );
    }

    _seenBroadcasts.add(sos.messageId);
    _seenBroadcasts.add(key);

    final forwarded = sos.copyForSOSForward(currentNodeId: myNodeId);

    return RoutingResult(
      decision: sos.senderId == myNodeId
          ? RoutingDecision.deliverOnly
          : RoutingDecision.deliver,
      processedMessage: forwarded,
      reason: 'SOS_OVERRIDE from ${sos.senderId}',
    );
  }

  // ─── إدارة جدول التوجيه ──────────────────────────
  void updateRoute(String targetNodeId, String viaNodeId) {
    _routingTable[targetNodeId] = viaNodeId;
  }

  String? getNextHop(String targetNodeId) {
    return _routingTable[targetNodeId];
  }

  void removeRoute(String nodeId) {
    _routingTable.remove(nodeId);
  }

  // ─── تنظيف دوري لـ seenBroadcasts ───────────────
  // يُستدعى كل 5 دقائق لمنع تراكم الذاكرة
  void cleanupSeenBroadcasts() {
    if (_seenBroadcasts.length > 1000) {
      // احتفظ بآخر 200 فقط
      final list = _seenBroadcasts.toList();
      _seenBroadcasts.clear();
      _seenBroadcasts.addAll(list.skip(list.length - 200));
    }
  }

  // ─── إحصائيات للـ Logs ────────────────────────────
  Map<String, int> get stats => {
    'processed': _totalProcessed,
    'dropped': _totalDropped,
    'forwarded': _totalForwarded,
    'seenBroadcasts': _seenBroadcasts.length,
    'routes': _routingTable.length,
  };

  void reset() {
    _seenBroadcasts.clear();
    _routingTable.clear();
    _totalProcessed = 0;
    _totalDropped = 0;
    _totalForwarded = 0;
  }
}
