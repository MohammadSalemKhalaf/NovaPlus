import 'package:flutter/material.dart';

import '../storage/secure_storage.dart';

class ThemeState extends ChangeNotifier {
  ThemeState({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  bool _initialized = false;
  bool _isDarkMode = false;

  bool get initialized => _initialized;
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> initialize() async {
    final savedMode = await _secureStorage.getEndUserThemeMode();
    _isDarkMode = savedMode == 'dark';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) {
      return;
    }

    _isDarkMode = isDark;
    notifyListeners();
    await _secureStorage.saveEndUserThemeMode(isDark ? 'dark' : 'light');
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }
}
