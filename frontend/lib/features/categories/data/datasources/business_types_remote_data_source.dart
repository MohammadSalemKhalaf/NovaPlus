import '../../../../core/api/api_client.dart';
import '../models/business_types_response_model.dart';

class BusinessTypesRemoteDataSource {
  BusinessTypesRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<BusinessTypesResponseModel> getBusinessTypes() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/business-types',
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty business types response');
    }

    return BusinessTypesResponseModel.fromJson(responseData);
  }
}
