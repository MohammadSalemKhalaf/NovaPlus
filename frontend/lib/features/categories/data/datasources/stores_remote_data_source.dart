import '../../../../core/api/api_client.dart';
import '../models/store_model.dart';
import '../models/stores_response_model.dart';

class StoresRemoteDataSource {
  StoresRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<StoresResponseModel> getStores({
    String? search,
    int? businessTypeId,
  }) async {
    final queryParameters = <String, dynamic>{
      if (businessTypeId != null) 'business_type_id': businessTypeId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/stores',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty stores response');
    }

    return StoresResponseModel.fromJson(responseData);
  }

  Future<StoreModel?> getStoreBySlug(String slug) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      return null;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/stores/$normalizedSlug',
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty store response');
    }

    final data = responseData['data'];
    if (data is Map) {
      return StoreModel.fromJson(Map<String, dynamic>.from(data));
    }

    return null;
  }
}
