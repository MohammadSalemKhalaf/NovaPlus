import '../../../core/api/api_client.dart';

class FavoritesApi {
  FavoritesApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getFavorites() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/enduser/favorites');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> addFavorite(String tenantId, {bool notificationsOptIn = false}) async {
    print('FINAL TENANT USED: $tenantId');
    await _apiClient.post<Map<String, dynamic>>(
      '/enduser/favorites',
      data: <String, dynamic>{
        'tenant_id': tenantId,
        'notifications_optin': notificationsOptIn,
      },
    );
  }

  Future<Map<String, dynamic>> checkFavorite(String tenantId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/enduser/favorites/check/$tenantId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> updateFavorite(String tenantId, {required bool notificationsOptIn}) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/enduser/favorites/$tenantId',
      data: <String, dynamic>{
        'notifications_optin': notificationsOptIn,
      },
    );
  }

  Future<void> removeFavorite(String tenantId) async {
    await _apiClient.delete<Map<String, dynamic>>('/enduser/favorites/$tenantId');
  }
}
