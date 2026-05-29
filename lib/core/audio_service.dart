// ═══════════════════════════════════════════════════════
// audio_service.dart — خدمة الصوت
// AAC-LC 12kbps + EOF Stitching لمنع Socket Fragmentation
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'mesh_service.dart';

class AudioService {
  static const String _eofMarker = '<EOF>';
  static const int _maxRecordSeconds = 15; // الحد الأقصى للتسجيل

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Buffer لجمع أشلاء الصوت الواردة
  final Map<String, StringBuffer> _audioBuffers = {};
  // batched base64 decode queue
  final List<_PendingAudio> _audioDecodeQueue = [];
  Timer? _audioFlushTimer;
  static const Duration _audioFlushInterval = Duration(milliseconds: 200);

  bool _isRecording = false;
  late MeshService _meshService;
  Timer? _recordingTimer;

  void setMeshService(MeshService service) => _meshService = service;

  // ─── بدء التسجيل ─────────────────────────────────
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.aac');

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 12000,    // 12kbps — ملف أقل من 50KB
          sampleRate: 16000,
        ),
        path: path,
      );

      _isRecording = true;
      _meshService.addLog('AUDIO: Recording started (max 15s)', LogLevel.info);

      // إيقاف تلقائي بعد 15 ثانية
      _recordingTimer = Timer(
        const Duration(seconds: _maxRecordSeconds),
        () => stopRecording(),
      );

      return true;
    } catch (e) {
      _meshService.addLog('AUDIO RECORD ERROR: $e', LogLevel.error);
      return false;
    }
  }

  // ─── إيقاف التسجيل وإرجاع Base64 ────────────────
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _recordingTimer?.cancel();
    _isRecording = false;

    try {
      final path = await _recorder.stop();
      if (path == null) return null;

      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      _meshService.addLog(
        'AUDIO: Recording stopped. Size: ${bytes.length}B '
        '(${(bytes.length / 1024).toStringAsFixed(1)}KB)',
        LogLevel.info,
      );

      // حذف الملف المؤقت
      await file.delete();

      // أضف EOF Marker
      return '$base64Audio$_eofMarker';
    } catch (e) {
      _meshService.addLog('AUDIO STOP ERROR: $e', LogLevel.error);
      return null;
    }
  }

  // ─── تشغيل صوت من Base64 ─────────────────────────
  Future<void> playAudioFromBase64(String base64WithEof) async {
    // enqueue decode request and return; decoded audio will be played
    final base64Clean = base64WithEof.replaceAll(_eofMarker, '');
    _enqueueAudioDecode(base64Clean);
  }

  void _enqueueAudioDecode(String base64Clean) {
    _audioDecodeQueue.add(_PendingAudio(base64Clean));
    _audioFlushTimer ??= Timer(_audioFlushInterval, _flushAudioDecodeQueue);
  }

  Future<void> _flushAudioDecodeQueue() async {
    final batch = List<_PendingAudio>.from(_audioDecodeQueue);
    _audioDecodeQueue.clear();
    _audioFlushTimer?.cancel();
    _audioFlushTimer = null;
    if (batch.isEmpty) return;

    final raws = batch.map((e) => e.base64).toList();
    List<List<int>> decoded = [];
    try {
      decoded = await compute(_base64DecodeBatchWorker, raws);
    } catch (e, st) {
      _meshService.addLog('AUDIO BATCH DECODE ERROR: $e\n$st', LogLevel.error);
      for (final r in raws) {
        try {
          decoded.add(base64Decode(r));
        } catch (_) {
          decoded.add(<int>[]);
        }
      }
    }

    for (final bytes in decoded) {
      if (bytes.isEmpty) continue;
      try {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'play_${DateTime.now().millisecondsSinceEpoch}.aac');
        final file = File(path);
        await file.writeAsBytes(bytes);
        await _player.play(DeviceFileSource(path));
        _meshService.addLog('AUDIO: Playing voice message (${bytes.length}B)', LogLevel.debug);
        _player.onPlayerComplete.listen((_) async { try { await file.delete(); } catch (_) {} });
      } catch (e) {
        _meshService.addLog('AUDIO PLAY ERROR (post-decode): $e', LogLevel.error);
      }
    }
  }

  // ─── EOF Stitching ────────────────────────────────
  // يجمع أشلاء الصوت الواردة حتى يجد EOF
  String? processAudioChunk(String messageId, String chunk) {
    _audioBuffers.putIfAbsent(messageId, () => StringBuffer());
    _audioBuffers[messageId]!.write(chunk);

    final buffer = _audioBuffers[messageId]!.toString();

    if (buffer.contains(_eofMarker)) {
      // اكتمل الصوت
      _audioBuffers.remove(messageId);
      return buffer;
    }

    return null; // لم يكتمل بعد
  }

  // ─── تشغيل صوت تنبيه SOS ─────────────────────────
  Future<void> playSOSAlarm() async {
    try {
      await _player.play(AssetSource('sounds/sos_alarm.mp3'));
    } catch (e) {
      _meshService.addLog('SOS ALARM ERROR: $e', LogLevel.error);
    }
  }

  // ─── تشغيل صوت رسالة واردة ───────────────────────
  Future<void> playMessageReceived() async {
    try {
      await _player.play(AssetSource('sounds/message_received.mp3'));
    } catch (e) {
      _meshService.addLog('MSG SOUND ERROR: $e', LogLevel.error);
    }
  }

  bool get isRecording => _isRecording;

  Future<void> dispose() async {
    _recordingTimer?.cancel();
    await _recorder.dispose();
    await _player.dispose();
  }
}

List<List<int>> _base64DecodeBatchWorker(List<String> raws) {
  final out = <List<int>>[];
  for (final r in raws) {
    try {
      out.add(base64Decode(r));
    } catch (_) {
      out.add(<int>[]);
    }
  }
  return out;
}

class _PendingAudio {
  final String base64;
  _PendingAudio(this.base64);
}
