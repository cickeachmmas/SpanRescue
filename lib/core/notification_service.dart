// ═══════════════════════════════════════════════════════
// notification_service.dart — تنبيهات SOS المحلية
// يُطلِق تنبيهاً حتى لو التطبيق في الخلفية
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../models/mesh_message.dart';
import 'mesh_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  late MeshService _meshService;
  bool _initialized = false;

  void setMeshService(MeshService service) => _meshService = service;

  // ─── تهيئة ───────────────────────────────────────
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // إنشاء قناة الإشعارات
    const channel = AndroidNotificationChannel(
      'span_sos_channel',
      'SOS Emergency Alerts',
      description: 'Critical emergency notifications from SPAN Rescue',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
    _meshService.addLog('NOTIFICATION SERVICE: Initialized', LogLevel.info);
  }

  // ─── إطلاق تنبيه SOS ─────────────────────────────
  Future<void> showSOSNotification(MeshMessage sos) async {
    if (!_initialized) return;

    // اهتزاز متكرر
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 1000],
        repeat: 2,
      );
    }

    const androidDetails = AndroidNotificationDetails(
      'span_sos_channel',
      'SOS Emergency Alerts',
      channelDescription: 'Critical emergency notifications',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(''),
      color: Color.fromARGB(255, 183, 28, 28),
      ledColor: Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 200,
      ledOffMs: 100,
    );

    await _plugin.show(
      sos.timestamp.hashCode,
      '🚨 EMERGENCY SOS — ${sos.senderId}',
      sos.content,
      const NotificationDetails(android: androidDetails),
      payload: sos.messageId,
    );

    _meshService.addLog(
      'NOTIFICATION: SOS alert shown for ${sos.senderId}',
      LogLevel.sos,
    );
  }

  // ─── تنبيه رسالة عادية ───────────────────────────
  Future<void> showMessageNotification(MeshMessage message) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'span_msg_channel',
      'Mesh Messages',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );

    await _plugin.show(
      message.timestamp.hashCode,
      '📩 ${message.senderId}',
      message.content,
      const NotificationDetails(android: androidDetails),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    _meshService.addLog(
      'NOTIFICATION TAPPED: ${response.payload}',
      LogLevel.info,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── إيقاف اهتزاز SOS وإلغاء الإشعارات المرتبطة ─────────
  Future<void> stopSOS() async {
    try {
      // Stop vibration immediately
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    _meshService.addLog('NOTIFICATION: SOS stopped', LogLevel.info);
  }
}
