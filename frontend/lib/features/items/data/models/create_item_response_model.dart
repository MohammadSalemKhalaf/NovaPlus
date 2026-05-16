class CreateItemResponseModel {
  const CreateItemResponseModel({
    required this.success,
    required this.message,
    this.itemId,
  });

  final bool success;
  final String message;
  final int? itemId;

  factory CreateItemResponseModel.fromJson(Map<String, dynamic> json) {
    int? itemId;

    final data = json['data'];
    if (data is Map) {
      if (data['id'] is num) {
        itemId = (data['id'] as num).toInt();
      } else {
        final item = data['item'];
        if (item is Map && item['id'] is num) {
          itemId = (item['id'] as num).toInt();
        }
      }
    }

    return CreateItemResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      itemId: itemId,
    );
  }
}
