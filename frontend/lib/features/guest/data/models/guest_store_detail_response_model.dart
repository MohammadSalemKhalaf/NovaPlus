import 'catalog_summary_model.dart';
import 'guest_store_detail_model.dart';

class GuestStoreDetailResponseModel {
  const GuestStoreDetailResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final GuestStoreDetailModel data;

  factory GuestStoreDetailResponseModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    final dataModel = dataJson is Map
        ? GuestStoreDetailModel.fromJson(Map<String, dynamic>.from(dataJson))
        : GuestStoreDetailModel(
            id: 0,
            name: '',
            slug: '',
            businessMode: '',
            catalogSummary: const CatalogSummaryModel(
              categoriesCount: 0,
              publicItemsCount: 0,
            ),
            catalogEndpoints: const CatalogEndpointsModel(
              items: '',
              categories: '',
            ),
          );

    return GuestStoreDetailResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataModel,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data.toJson(),
  };
}
