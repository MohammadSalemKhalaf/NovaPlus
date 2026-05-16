import 'guest_category_model.dart';
import 'response_meta.dart';

class GuestCategoriesResponseModel {
  const GuestCategoriesResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.meta,
  });

  final bool success;
  final String message;
  final List<GuestCategoryModel> data;
  final ResponseMeta meta;

  factory GuestCategoriesResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final dataList = rawData is List
        ? rawData
            .whereType<Map>()
            .map((item) =>
                GuestCategoryModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <GuestCategoryModel>[];

    final metaJson = json['meta'];
    final metaModel = metaJson is Map
        ? ResponseMeta.fromJson(Map<String, dynamic>.from(metaJson))
        : ResponseMeta();

    return GuestCategoriesResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataList,
      meta: metaModel,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data.map((e) => e.toJson()).toList(),
    'meta': meta.toJson(),
  };
}
