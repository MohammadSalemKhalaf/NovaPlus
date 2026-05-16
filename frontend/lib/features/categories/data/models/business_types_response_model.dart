import 'business_type_model.dart';

class BusinessTypesResponseModel {
  const BusinessTypesResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final List<BusinessTypeModel> data;

  factory BusinessTypesResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final dataList = rawData is List
        ? rawData
            .whereType<Map>()
            .map(
              (item) => BusinessTypeModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <BusinessTypeModel>[];

    return BusinessTypesResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataList,
    );
  }
}
