class SetActivePriceResponseModel {
  const SetActivePriceResponseModel({
    required this.success,
    required this.message,
    this.priceId,
  });

  final bool success;
  final String message;
  final int? priceId;

  factory SetActivePriceResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    int? priceId;

    if (data is Map && data['price'] is Map) {
      final price = data['price'] as Map;
      final idRaw = price['id'];
      if (idRaw is num) {
        priceId = idRaw.toInt();
      }
    }

    return SetActivePriceResponseModel(
      success: json['success'] == true || !json.containsKey('success'),
      message: (json['message'] as String?) ?? 'Price set successfully',
      priceId: priceId,
    );
  }
}
