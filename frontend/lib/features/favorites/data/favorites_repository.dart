import 'package:dio/dio.dart';

import '../domain/entities/favorite_entity.dart';
import 'favorites_api.dart';

class FavoritesRepository {
  FavoritesRepository({required FavoritesApi api}) : _api = api;

  final FavoritesApi _api;

  Future<List<FavoriteEntity>> getFavorites() async {
    final payload = await _api.getFavorites();
    final items = _extractFavoritesArray(payload);

    final favorites = <FavoriteEntity>[];
    for (final item in items) {
      final tenantId = _readTenantId(item);
      if (tenantId == null || tenantId.isEmpty) {
        continue;
      }

      favorites.add(
        FavoriteEntity(
          tenantId: tenantId,
          notificationsOptIn: _readNotificationsOptIn(item),
        ),
      );
    }

    return favorites;
  }

  Future<void> addFavorite(String tenantId, {bool notificationsOptIn = false}) {
    return _api.addFavorite(tenantId, notificationsOptIn: notificationsOptIn);
  }

  Future<bool> checkFavorite(String tenantId) async {
    final payload = await _api.checkFavorite(tenantId);
    final data = payload['data'];

    if (data is Map<String, dynamic>) {
      return _toBool(data['is_favorite']);
    }
    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      return _toBool(mapped['is_favorite']);
    }

    return false;
  }

  Future<void> updateFavorite(String tenantId, {required bool notificationsOptIn}) {
    return _api.updateFavorite(tenantId, notificationsOptIn: notificationsOptIn);
  }

  Future<void> removeFavorite(String tenantId) {
    return _api.removeFavorite(tenantId);
  }

  List<Map<String, dynamic>> _extractFavoritesArray(Map<String, dynamic> payload) {
    final data = payload['data'];

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (data is Map<String, dynamic>) {
      final nested = data['favorites'] ?? data['items'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      final nested = mapped['favorites'] ?? mapped['items'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    return const <Map<String, dynamic>>[];
  }

  String? _readTenantId(Map<String, dynamic> item) {
    final direct = item['tenant_id'];
    if (direct != null) {
      return direct.toString();
    }

    final tenant = item['tenant'];
    if (tenant is Map<String, dynamic> && tenant['id'] != null) {
      return tenant['id'].toString();
    }
    if (tenant is Map) {
      final mapped = Map<String, dynamic>.from(tenant);
      if (mapped['id'] != null) {
        return mapped['id'].toString();
      }
    }

    return null;
  }

  bool _readNotificationsOptIn(Map<String, dynamic> item) {
    return _toBool(item['notifications_optin']);
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  int? mapStatusCode(Object error) {
    if (error is DioException) {
      return error.response?.statusCode;
    }
    return null;
  }
}
