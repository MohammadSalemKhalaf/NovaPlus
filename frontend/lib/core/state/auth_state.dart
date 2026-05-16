import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';

enum UserMode {
  authenticated,
  guest,
}

class AuthState extends ChangeNotifier {
  AuthState({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  bool _initialized = false;
  bool _isAuthenticated = false;
  bool _isGuest = true;
  UserMode _mode = UserMode.guest;
  String? _role;
  String? _name;
  String? _email;

  bool get initialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  UserMode get mode => _mode;
  bool get isGuest => _isGuest;
  String? get role => _role;
  String? get name => _name;
  String? get email => _email;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final token = await _secureStorage.getToken();
    final role = _normalizeRole((await _secureStorage.getUserRole())?.trim());
    final ownerName = (await _secureStorage.getOwnerName())?.trim();
    final ownerEmail = (await _secureStorage.getOwnerEmail())?.trim();

    _isAuthenticated = token != null && token.isNotEmpty;
    _isGuest = !_isAuthenticated;
    _mode = _isAuthenticated ? UserMode.authenticated : UserMode.guest;
    _role = role;
    _name = ownerName == null || ownerName.isEmpty ? null : ownerName;
    _email = ownerEmail == null || ownerEmail.isEmpty ? null : ownerEmail;
    _initialized = true;

    notifyListeners();
  }

  Future<void> setAuthenticated({
    required String role,
    String? name,
    String? email,
  }) async {
    _isAuthenticated = true;
    _isGuest = false;
    _mode = UserMode.authenticated;
    _role = _normalizeRole(role);
    _name = (name ?? '').trim().isEmpty ? _name : name?.trim();
    _email = (email ?? '').trim().isEmpty ? _email : email?.trim();
    _initialized = true;
    notifyListeners();
  }

  Future<void> setUnauthenticated() async {
    _isAuthenticated = false;
    _isGuest = true;
    _mode = UserMode.guest;
    _role = null;
    _name = null;
    _email = null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? email}) async {
    final normalizedName = name?.trim();
    final normalizedEmail = email?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      _name = normalizedName;
      await _secureStorage.saveOwnerName(normalizedName);
    }

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      _email = normalizedEmail;
      await _secureStorage.saveOwnerEmail(normalizedEmail);
    }

    notifyListeners();
  }

  String? _normalizeRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == 'store_owner') {
      return 'owner';
    }

    if (normalized == 'super_admin') {
      return 'admin';
    }

    if (normalized == 'owner' ||
        normalized == 'admin' ||
        normalized == 'sales_agent' ||
        normalized == 'end_user') {
      return normalized;
    }

    return normalized;
  }
}
