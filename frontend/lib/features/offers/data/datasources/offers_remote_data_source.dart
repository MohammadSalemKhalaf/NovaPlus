import '../../../../core/api/api_client.dart';
import '../models/offer_model.dart';

class OffersRemoteDataSource {
  OffersRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<OfferModel>> getOffers({
    String? search,
    String? status,
    int perPage = 100,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/owner/offers',
      queryParameters: <String, dynamic>{
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty && status.trim().toLowerCase() != 'all')
          'status': status.trim().toLowerCase(),
      },
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty offers response');
    }

    final data = responseData['data'];
    final rawOffers = data is Map ? data['offers'] : responseData['offers'];
    final offers = rawOffers is List ? rawOffers : const <dynamic>[];

    return offers
        .whereType<Map>()
        .map((entry) => OfferModel.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  Future<OfferModel> createOffer(Map<String, dynamic> payload) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/owner/offers',
      data: payload,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty create offer response');
    }

    if (responseData['success'] != true) {
      throw Exception(
        responseData['message']?.toString().isNotEmpty == true
            ? responseData['message'].toString()
            : 'Failed to create offer',
      );
    }

    final data = responseData['data'];
    final offer = data is Map ? data['offer'] : null;
    if (offer is Map) {
      return OfferModel.fromJson(Map<String, dynamic>.from(offer));
    }

    throw Exception('Offer created but response did not include offer data');
  }

  Future<OfferModel> updateOffer({
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/owner/offers/$id',
      data: payload,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty update offer response');
    }

    if (responseData['success'] != true) {
      throw Exception(
        responseData['message']?.toString().isNotEmpty == true
            ? responseData['message'].toString()
            : 'Failed to update offer',
      );
    }

    final data = responseData['data'];
    final offer = data is Map ? data['offer'] : null;
    if (offer is Map) {
      return OfferModel.fromJson(Map<String, dynamic>.from(offer));
    }

    throw Exception('Offer updated but response did not include offer data');
  }

  Future<void> deleteOffer(int id) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/owner/offers/$id',
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty delete offer response');
    }

    if (responseData['success'] != true) {
      throw Exception(
        responseData['message']?.toString().isNotEmpty == true
            ? responseData['message'].toString()
            : 'Failed to delete offer',
      );
    }
  }
}