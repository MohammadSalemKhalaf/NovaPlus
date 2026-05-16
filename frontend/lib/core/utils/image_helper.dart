import '../config/app_config.dart';

class ImageHelper {
  const ImageHelper._();

  static String? build(String? path) {
    var raw = path?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    // Some APIs may return quoted or escaped URL fragments.
    raw = raw.replaceAll('\\/', '/');
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      raw = raw.substring(1, raw.length - 1).trim();
    }

    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    if (raw.startsWith('/storage/')) {
      final host = AppConfig.baseUrl.replaceFirst('/api/v1', '');
      return '$host$raw';
    }

    if (raw.startsWith('storage/')) {
      final host = AppConfig.baseUrl.replaceFirst('/api/v1', '');
      return '$host/$raw';
    }

    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;

    return '${AppConfig.storageUrl}$normalized';
  }
}
