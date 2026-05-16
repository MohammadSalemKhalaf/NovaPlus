import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/notifications/enduser_chat_notification_watcher.dart';
import 'core/notifications/local_notifications_service.dart';
import 'core/state/auth_state.dart';
import 'core/state/cart_state.dart';
import 'core/state/store_cubit.dart';
import 'core/state/theme_state.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>(
          create: (_) => AuthState(secureStorage: SecureStorage())..initialize(),
        ),
        ChangeNotifierProvider<CartState>(
          create: (_) => CartState(secureStorage: SecureStorage())..initialize(),
        ),
        ChangeNotifierProvider<StoreCubit>(
          create: (_) => StoreCubit(),
        ),
        ChangeNotifierProvider<ThemeState>(
          create: (_) => ThemeState(secureStorage: SecureStorage())..initialize(),
        ),
      ],
      child: const NovaPlusApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(LocalNotificationsService.instance.initialize());
    unawaited(EndUserChatNotificationWatcher.instance.start());
  });
}
