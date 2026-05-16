import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _tokenKey = 'auth_token';
  static const String _tenantIdKey = 'tenant_id';
  static const String _adminTokenKey = 'admin_token';
  static const String _userTenantsKey = 'user_tenants';
  static const String _userRoleKey = 'user_role';
  static const String _roleKey = 'role';
  static const String _ownerNameKey = 'owner_name';
  static const String _ownerEmailKey = 'owner_email';
  static const String _deviceIdKey = 'device_id';
  static const String _favoriteStoreIdsKey = 'favorite_store_ids';
  static const String _localOrderHistoryKey = 'local_order_history';
  static const String _ownerThemeModeKey = 'owner_theme_mode';
  static const String _endUserThemeModeKey = 'end_user_theme_mode';
  static const String _endUserOnboardingSeenKey = 'end_user_onboarding_seen';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }

    return _storage.read(key: _tokenKey);
  }

  Future<void> saveTenantId(String tenantId) {
    return _storage.write(key: _tenantIdKey, value: tenantId);
  }

  Future<String?> getTenantId() {
    return _storage.read(key: _tenantIdKey);
  }

  Future<void> saveAdminToken(String token) {
    return _storage.write(key: _adminTokenKey, value: token);
  }

  Future<String?> getAdminToken() {
    return _storage.read(key: _adminTokenKey);
  }

  Future<void> saveUserTenants(String tenantsJson) {
    return _storage.write(key: _userTenantsKey, value: tenantsJson);
  }

  Future<String?> getUserTenants() {
    return _storage.read(key: _userTenantsKey);
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
    await _storage.write(key: _roleKey, value: role);
  }

  Future<String?> getUserRole() async {
    final role = await _storage.read(key: _userRoleKey);
    if (role != null && role.trim().isNotEmpty) {
      return role;
    }

    // Backward compatibility for sessions saved before _userRoleKey was used.
    return _storage.read(key: _roleKey);
  }

  Future<void> saveOwnerName(String name) {
    return _storage.write(key: _ownerNameKey, value: name);
  }

  Future<String?> getOwnerName() {
    return _storage.read(key: _ownerNameKey);
  }

  Future<void> saveOwnerEmail(String email) {
    return _storage.write(key: _ownerEmailKey, value: email);
  }

  Future<String?> getOwnerEmail() {
    return _storage.read(key: _ownerEmailKey);
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tenantIdKey);
    await _storage.delete(key: _adminTokenKey);
    await _storage.delete(key: _userTenantsKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _ownerNameKey);
    await _storage.delete(key: _ownerEmailKey);
  }

  Future<void> saveOwnerThemeMode(String mode) {
    return _storage.write(key: _ownerThemeModeKey, value: mode);
  }

  Future<String?> getOwnerThemeMode() {
    return _storage.read(key: _ownerThemeModeKey);
  }

  Future<void> saveEndUserThemeMode(String mode) {
    return _storage.write(key: _endUserThemeModeKey, value: mode);
  }

  Future<String?> getEndUserThemeMode() {
    return _storage.read(key: _endUserThemeModeKey);
  }

  Future<void> clearSession() async {
    await clearAuthData();
  }

  /// Check if user is logged in (has valid token)
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveDeviceId(String deviceId) {
    return _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> getDeviceId() {
    return _storage.read(key: _deviceIdKey);
  }

  Future<void> clearDeviceId() {
    return _storage.delete(key: _deviceIdKey);
  }

  Future<void> saveFavoriteStoreIds(List<String> tenantIds) async {
    final normalized = tenantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    await _storage.write(
      key: _favoriteStoreIdsKey,
      value: jsonEncode(normalized),
    );
  }

  Future<List<String>> getFavoriteStoreIds() async {
    final raw = await _storage.read(key: _favoriteStoreIdsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }

      return decoded
          .map((item) => item.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> clearFavoriteStoreIds() {
    return _storage.delete(key: _favoriteStoreIdsKey);
  }

  Future<void> appendLocalOrder(Map<String, dynamic> order) async {
    final orders = List<Map<String, dynamic>>.from(await getLocalOrders());
    orders.insert(0, order);

    // Keep only latest 100 orders to avoid unbounded storage growth.
    final trimmed = orders.take(100).toList(growable: false);
    await _storage.write(key: _localOrderHistoryKey, value: jsonEncode(trimmed));
  }

  Future<List<Map<String, dynamic>>> getLocalOrders() async {
    final raw = await _storage.read(key: _localOrderHistoryKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> setEndUserOnboardingSeen(bool value) {
    return _storage.write(
      key: _endUserOnboardingSeenKey,
      value: value ? 'true' : 'false',
    );
  }

  Future<bool> getEndUserOnboardingSeen() async {
    final raw = await _storage.read(key: _endUserOnboardingSeenKey);
    return raw == 'true';
  }
}
