import '../../../../core/storage/secure_storage.dart';

class DeviceService {
  DeviceService({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;
  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    final storedDeviceId = await _secureStorage.getDeviceId();
    if (storedDeviceId != null && storedDeviceId.trim().isNotEmpty) {
      _cachedDeviceId = storedDeviceId.trim();
      return _cachedDeviceId!;
    }

    final generated = DateTime.now().microsecondsSinceEpoch.toString();
    _cachedDeviceId = generated;
    await _secureStorage.saveDeviceId(generated);
    return generated;
  }
}
