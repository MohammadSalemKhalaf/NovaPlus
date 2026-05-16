class AppConfig {
  const AppConfig._();

  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String storageUrl = 'http://10.0.2.2:8000/storage/';
  static const String firebaseRealtimeDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue:
        'https://novaplus-d4cf2-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static String get publicBaseUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    }

    final emulatorSafeHost =
        (uri.host == '127.0.0.1' || uri.host == 'localhost')
        ? '10.0.2.2'
        : uri.host;

    final normalized = Uri(
      scheme: uri.scheme,
      host: emulatorSafeHost,
      port: uri.hasPort ? uri.port : null,
    );

    return normalized.toString();
  }

  static String storePublicUrl(String tenantSlug) {
    final slug = tenantSlug.trim();
    if (slug.isEmpty) {
      return '';
    }

    return Uri.parse(publicBaseUrl).replace(path: '/store/$slug').toString();
  }

  // Android emulator uses 10.0.2.2 instead of 127.0.0.1.
}
