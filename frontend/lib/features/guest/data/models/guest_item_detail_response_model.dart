import 'guest_item_detail_model.dart';

class GuestItemDetailResponseModel {
  const GuestItemDetailResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final GuestItemDetailModel data;

  factory GuestItemDetailResponseModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    final dataModel = dataJson is Map
        ? GuestItemDetailModel.fromJson(Map<String, dynamic>.from(dataJson))
        : GuestItemDetailModel(
            id: 0,
            tenantId: 0,
            name: '',
            slug: '',
            description: '',
          );

    return GuestItemDetailResponseModel(
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
