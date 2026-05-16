import 'store_model.dart';

class StoresResponseModel {
  const StoresResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final List<StoreModel> data;

  factory StoresResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final dataList = rawData is List
        ? rawData
            .whereType<Map>()
            .map((item) => StoreModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <StoreModel>[];

    return StoresResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataList,
    );
  }
}
