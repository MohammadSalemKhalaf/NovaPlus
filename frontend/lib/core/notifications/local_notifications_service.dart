import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/app_navigator.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      'chat_messages_channel',
      'Chat Messages',
      description: 'Realtime chat message notifications',
      importance: Importance.max,
      playSound: true,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showChatNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final hasPermission = await _ensureAndroidPermission();
    if (!hasPermission) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages_channel',
        'Chat Messages',
        channelDescription: 'Realtime chat message notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload == null ? null : jsonEncode(payload),
    );
  }

  Future<bool> requestPermission() async {
    if (!_initialized) {
      await initialize();
    }

    return _ensureAndroidPermission();
  }

  Future<bool> _ensureAndroidPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return true;
    }

    final enabled = await androidPlugin.areNotificationsEnabled();
    if (enabled == true) {
      return true;
    }

    await androidPlugin.requestNotificationsPermission();
    final enabledAfterRequest = await androidPlugin.areNotificationsEnabled();
    return enabledAfterRequest == true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payloadRaw = response.payload;
    if (payloadRaw == null || payloadRaw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) {
        return;
      }

      final payload = Map<String, dynamic>.from(decoded);
      final conversationId = int.tryParse(payload['conversation_id']?.toString() ?? '');
      if (conversationId == null || conversationId <= 0) {
        return;
      }

      final chatTitle = payload['chat_title']?.toString();
      AppNavigator.openGuestConversation(
        conversationId: conversationId,
        chatTitle: chatTitle,
      );
    } catch (_) {
      // Ignore malformed payloads silently.
    }
  }
}
