// ═══════════════════════════════════════════════════════
// store_forward_queue.dart — DTN Persistence Layer
// يخزن الرسائل عند انقطاع الاتصال ويعيد إرسالها
// ═══════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mesh_message.dart';

class StoreForwardQueue {
  static const String _queueKey = 'sfq_messages';
  static const int _maxQueueSize = 100;

  final SharedPreferences _prefs;
  final List<MeshMessage> _queue = [];

  StoreForwardQueue(this._prefs) {
    _loadFromDisk();
  }

  // ─── إضافة رسالة للـ Queue ───────────────────────
  void enqueue(MeshMessage message) {
    // SOS دائماً في الأول — Priority Queue
    if (message.isSOS) {
      _queue.insert(0, message);
    } else {
      _queue.add(message);
    }

    // لا تتجاوز الحد الأقصى — احذف الأقدم غير SOS
    if (_queue.length > _maxQueueSize) {
      final nonSOS = _queue.indexWhere((m) => !m.isSOS);
      if (nonSOS != -1) _queue.removeAt(nonSOS);
    }

    _saveToDisk();
  }

  // ─── إفراغ الـ Queue عبر Socket ──────────────────
  Future<int> flushToSocket(Socket socket) async {
    if (_queue.isEmpty) return 0;

    final toSend = List<MeshMessage>.from(_queue);
    int sent = 0;

    for (final message in toSend) {
      try {
        final raw = '${message.toJsonString()}\n';
        socket.add(utf8.encode(raw));
        _queue.remove(message);
        sent++;
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        break; // توقف عند أول فشل
      }
    }

    if (sent > 0) _saveToDisk();
    return sent;
  }

  // ─── إفراغ عبر Callback عام ───────────────────────
  Future<int> flushWithCallback(
    Future<bool> Function(MeshMessage) sendCallback,
  ) async {
    if (_queue.isEmpty) return 0;

    final toSend = List<MeshMessage>.from(_queue);
    int sent = 0;

    for (final message in toSend) {
      final success = await sendCallback(message);
      if (success) {
        _queue.remove(message);
        sent++;
      } else {
        break;
      }
    }

    if (sent > 0) _saveToDisk();
    return sent;
  }

  // ─── حفظ على الـ Disk ────────────────────────────
  void _saveToDisk() {
    try {
      final jsonList = _queue.map((m) => m.toJson()).toList();
      _prefs.setString(_queueKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  // ─── تحميل من الـ Disk ───────────────────────────
  void _loadFromDisk() {
    try {
      final saved = _prefs.getString(_queueKey);
      if (saved != null) {
        final list = jsonDecode(saved) as List;
        _queue.addAll(
          list.map((m) => MeshMessage.fromJson(m as Map<String, dynamic>)),
        );
      }
    } catch (_) {}
  }

  // ─── معلومات ─────────────────────────────────────
  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
  List<MeshMessage> get messages => List.unmodifiable(_queue);

  void clear() {
    _queue.clear();
    _saveToDisk();
  }
}
