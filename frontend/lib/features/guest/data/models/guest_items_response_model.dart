import 'guest_item_list_model.dart';
import 'response_meta.dart';

class GuestItemsResponseModel {
  const GuestItemsResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.meta,
  });

  final bool success;
  final String message;
  final List<GuestItemListModel> data;
  final ResponseMeta meta;

  static List<dynamic> _extractItemList(dynamic rawData) {
    if (rawData is List) {
      return rawData;
    }

    if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      final nested = map['items'];
      if (nested is List) {
        return nested;
      }
    }

    return const <dynamic>[];
  }

  factory GuestItemsResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = _extractItemList(json['data']);
    final dataList = rawData
        .whereType<Map>()
        .map((item) => GuestItemListModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    final metaJson = json['meta'];
    final metaModel = metaJson is Map
        ? ResponseMeta.fromJson(Map<String, dynamic>.from(metaJson))
        : ResponseMeta();

    return GuestItemsResponseModel(
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
