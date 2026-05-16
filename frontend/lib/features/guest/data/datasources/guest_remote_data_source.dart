import '../../../../core/api/api_client.dart';
import '../models/models.dart';

class GuestRemoteDataSource {
  GuestRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// GET /public/stores - List all public stores
  /// Supports pagination, search, and business type filter
  Future<GuestStoresResponseModel> listStores({
    String? search,
    int? businessTypeId,
    int perPage = 10,
  }) async {
    final queryParameters = <String, dynamic>{
      'per_page': perPage,
      if (businessTypeId != null) 'business_type_id': businessTypeId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/stores',
      queryParameters: queryParameters,
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty stores response');
    }

    return GuestStoresResponseModel.fromJson(responseData);
  }

  /// GET /public/stores/{slug} - Get store details by slug
  /// Returns store info including catalog summary and endpoints
  Future<GuestStoreDetailResponseModel> getStoreBySlug(String slug) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      throw Exception('Store slug cannot be empty');
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/stores/$normalizedSlug',
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty store detail response');
    }

    return GuestStoreDetailResponseModel.fromJson(responseData);
  }

  /// GET /public/tenants/{tenant_id}/categories - Get categories for a store
  /// Returns list of active categories with available items
  Future<GuestCategoriesResponseModel> getCategoriesForTenant(
    int tenantId, {
    int perPage = 15,
    String sort = 'name',
    String direction = 'asc',
  }) async {
    final queryParameters = <String, dynamic>{
      'per_page': perPage,
      'sort': sort,
      'direction': direction,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/tenants/$tenantId/categories',
      queryParameters: queryParameters,
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty categories response');
    }

    return GuestCategoriesResponseModel.fromJson(responseData);
  }

  /// GET /public/tenants/{tenant_id}/items - Get items for a store
  /// Supports filtering by category, search, sorting, and pagination
  Future<GuestItemsResponseModel> getItemsForTenant(
    int tenantId, {
    int? categoryId,
    String? search,
    int perPage = 15,
    String sort = 'latest',
    String direction = 'desc',
    bool featured = false,
  }) async {
    final queryParameters = <String, dynamic>{
      'per_page': perPage,
      'sort': sort,
      'direction': direction,
      if (categoryId != null) 'category_id': categoryId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (featured) 'featured': true,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/tenants/$tenantId/items',
      queryParameters: queryParameters,
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty items response');
    }

    return GuestItemsResponseModel.fromJson(responseData);
  }

  /// GET /public/tenants/{tenant_id}/items/{item_id} - Get full item details
  /// Returns complete item information including full description and image
  Future<GuestItemDetailResponseModel> getItemDetail(
    int tenantId,
    int itemId,
  ) async {
    if (tenantId <= 0 || itemId <= 0) {
      throw Exception('Invalid tenant_id or item_id');
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/tenants/$tenantId/items/$itemId',
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty item detail response');
    }

    return GuestItemDetailResponseModel.fromJson(responseData);
  }
}
