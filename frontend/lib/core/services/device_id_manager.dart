import 'dart:math';

import '../storage/secure_storage.dart';

/// Manages device ID for guest users and cart persistence.
/// 
/// Device ID is generated once and persisted across app sessions.
/// Used to track guest cart items and merge with user cart on login.
class DeviceIdManager {
  DeviceIdManager({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;
  String? _deviceId;

  /// Get or generate a device ID.
  /// 
  /// Generates a new UUID if none exists, then caches in memory.
  /// Subsequent calls return the cached value.
  Future<String> getDeviceId() async {
    // Return cached value if available
    if (_deviceId != null) {
      return _deviceId!;
    }

    // Try to load from persistent storage
    final stored = await _secureStorage.getDeviceId();
    if (stored != null && stored.isNotEmpty) {
      _deviceId = stored;
      return _deviceId!;
    }

    // Generate new device ID
    _deviceId = _generateUUID();
    await _secureStorage.saveDeviceId(_deviceId!);
    return _deviceId!;
  }

  /// Clear the device ID from storage and memory.
  /// Used when user logs out or resets the app.
  Future<void> clearDeviceId() async {
    _deviceId = null;
    await _secureStorage.clearDeviceId();
  }

  /// Generate a UUID-like string.
  /// Uses combination of timestamp and random values.
  static String _generateUUID() {
    final random = Random();
    const hexChars = '0123456789abcdef';
    
    // Generate random UUID in format: 8-4-4-4-12
    final uuid = StringBuffer();
    
    // 8 chars
    for (int i = 0; i < 8; i++) {
      uuid.write(hexChars[random.nextInt(16)]);
    }
    uuid.write('-');
    
    // 4 chars
    for (int i = 0; i < 4; i++) {
      uuid.write(hexChars[random.nextInt(16)]);
    }
    uuid.write('-');
    
    // 4 chars (with version 4 format)
    uuid.write('4');
    for (int i = 0; i < 3; i++) {
      uuid.write(hexChars[random.nextInt(16)]);
    }
    uuid.write('-');
    
    // 4 chars (with variant format)
    uuid.write(hexChars[random.nextInt(2) + 8]);
    for (int i = 0; i < 3; i++) {
      uuid.write(hexChars[random.nextInt(16)]);
    }
    uuid.write('-');
    
    // 12 chars
    for (int i = 0; i < 12; i++) {
      uuid.write(hexChars[random.nextInt(16)]);
    }
    
    return uuid.toString();
  }
}
