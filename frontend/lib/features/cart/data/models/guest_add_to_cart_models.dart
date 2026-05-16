/// Request model for adding item to cart.
class AddToGuestCartRequestModel {
  const AddToGuestCartRequestModel({
    required this.itemId,
    required this.quantity,
  });

  final String itemId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item_id': itemId,
      'quantity': quantity,
    };
  }
}

/// Response model for adding item to cart.
class AddToGuestCartResponseModel {
  const AddToGuestCartResponseModel({
    required this.success,
    this.data,
    this.message,
  });

  final bool success;
  final AddToGuestCartDataModel? data;
  final String? message;

  factory AddToGuestCartResponseModel.fromJson(Map<String, dynamic> json) {
    return AddToGuestCartResponseModel(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null
          ? AddToGuestCartDataModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Data model for add to cart response.
class AddToGuestCartDataModel {
  const AddToGuestCartDataModel({
    this.itemId,
    this.quantity,
    this.message,
    this.cart,
  });

  final String? itemId;
  final int? quantity;
  final String? message;
  final AddToGuestCartCartModel? cart;

  factory AddToGuestCartDataModel.fromJson(Map<String, dynamic> json) {
    return AddToGuestCartDataModel(
      itemId: _asNullableString(json['item_id']),
      quantity: _asNullableInt(json['quantity']),
      message: _asNullableString(json['message']),
      cart: json['cart'] is Map<String, dynamic>
          ? AddToGuestCartCartModel.fromJson(json['cart'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AddToGuestCartCartModel {
  const AddToGuestCartCartModel({
    this.items = const <AddToGuestCartItemModel>[],
  });

  final List<AddToGuestCartItemModel> items;

  int get totalQuantity =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  factory AddToGuestCartCartModel.fromJson(Map<String, dynamic> json) {
    final itemsData = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return AddToGuestCartCartModel(
      items: itemsData
          .whereType<Map<String, dynamic>>()
          .map(AddToGuestCartItemModel.fromJson)
          .toList(growable: false),
    );
  }
}

class AddToGuestCartItemModel {
  const AddToGuestCartItemModel({
    required this.quantity,
  });

  final int quantity;

  factory AddToGuestCartItemModel.fromJson(Map<String, dynamic> json) {
    return AddToGuestCartItemModel(
      quantity: _asNullableInt(json['quantity']) ?? 0,
    );
  }
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}
