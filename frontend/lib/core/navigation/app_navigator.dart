import 'package:flutter/material.dart';

import '../../features/guest/presentation/screens/guest_store_chat_screen.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool openGuestConversation({
    required int conversationId,
    String? chatTitle,
  }) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      return false;
    }

    navigatorState.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuestStoreChatScreen.fromConversation(
          initialConversationId: conversationId,
          chatTitle: chatTitle,
        ),
      ),
    );

    return true;
  }
}