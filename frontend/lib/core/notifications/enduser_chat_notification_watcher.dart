import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';
import '../../features/guest/presentation/services/guest_notifications_service.dart';
import 'chat_presence.dart';
import 'local_notifications_service.dart';

class EndUserChatNotificationWatcher {
  EndUserChatNotificationWatcher._();

  static final EndUserChatNotificationWatcher instance = EndUserChatNotificationWatcher._();

  Timer? _timer;
  bool _started = false;
  bool _baselineReady = false;
  int _lastUnread = 0;
  int _lastNotifiedNotificationId = 0;
  bool _isTicking = false;

  late final SecureStorage _secureStorage;
  late final GuestNotificationsService _notificationsService;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _secureStorage = SecureStorage();
    _notificationsService = GuestNotificationsService(
      apiClient: ApiClient(secureStorage: _secureStorage),
    );

    _started = true;
    await refreshNow(allowNotify: false);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshNow();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _baselineReady = false;
    _lastUnread = 0;
    _lastNotifiedNotificationId = 0;
  }

  Future<void> refreshNow({bool allowNotify = true}) async {
    if (!_started || _isTicking) {
      return;
    }

    _isTicking = true;
    try {
      final token = (await _secureStorage.getToken() ?? '').trim();

      if (token.isEmpty) {
        _baselineReady = false;
        _lastUnread = 0;
        return;
      }

      final unread = await _notificationsService.unreadCount();
      final notifications = await _notificationsService.listNotifications(perPage: 20);
      GuestNotificationItem? latestChat;
      for (final item in notifications) {
        if (item.type == 'chat_message' && !item.isRead && item.conversationId != null) {
          latestChat = item;
          break;
        }
      }

      if (!_baselineReady) {
        if (allowNotify && unread > 0 && !ChatPresence.isGuestChatOpen.value && latestChat != null) {
          final senderName = latestChat.senderName ?? 'Store';
          final conversationId = latestChat.conversationId;

          await LocalNotificationsService.instance.showChatNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
            title: 'You have message from $senderName',
            body: latestChat.body,
            payload: <String, dynamic>{
              'type': 'chat_message',
              'conversation_id': conversationId,
              'chat_title': latestChat.tenantName ?? 'Store',
              'sender_name': senderName,
              'notification_id': latestChat.id,
            },
          );
          _lastNotifiedNotificationId = latestChat.id;
        }

        _lastUnread = unread;
        _baselineReady = true;
        return;
      }

      final hasIncrease = unread > _lastUnread;
      final shouldNotifyForNewChat = latestChat != null && latestChat.id != _lastNotifiedNotificationId;

      if (allowNotify && hasIncrease && !ChatPresence.isGuestChatOpen.value && shouldNotifyForNewChat) {
        final senderName = latestChat.senderName ?? 'Store';
        final conversationId = latestChat.conversationId;

        await LocalNotificationsService.instance.showChatNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
          title: 'You have message from $senderName',
          body: latestChat.body,
          payload: <String, dynamic>{
            'type': 'chat_message',
            'conversation_id': conversationId,
            'chat_title': latestChat.tenantName ?? 'Store',
            'sender_name': senderName,
            'notification_id': latestChat.id,
          },
        );
        _lastNotifiedNotificationId = latestChat.id;
      }

      _lastUnread = unread;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('EndUserChatNotificationWatcher error: $error');
      }
    } finally {
      _isTicking = false;
    }
  }
}
