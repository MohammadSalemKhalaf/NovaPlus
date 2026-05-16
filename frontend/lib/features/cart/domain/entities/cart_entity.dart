/// Entity representing a cart (guest or authenticated user).
/// 
/// Contains summary of cart items and their details.
class CartEntity {
  const CartEntity({
    required this.totalItems,
    required this.totalPrice,
    required this.items,
  });

  /// Total number of items in the cart
  final int totalItems;

  /// Total price of all items
  final double totalPrice;

  /// List of cart items
  final List<CartItemEntity> items;

  /// Create empty cart
  factory CartEntity.empty() => const CartEntity(
    totalItems: 0,
    totalPrice: 0.0,
    items: [],
  );

  /// Parse cart from backend JSON response
  factory CartEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};

    final totalItems = _asInt(dataMap['total_items']);
    final totalPrice = _asDouble(dataMap['total_price']);
    final itemsList = (dataMap['items'] as List?)?.map(
      (item) => CartItemEntity.fromJson(item as Map<String, dynamic>),
    ).toList() ?? [];
    
    return CartEntity(
      totalItems: totalItems,
      totalPrice: totalPrice,
      items: itemsList,
    );
  }

  /// Helper to convert dynamic to int
  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Helper to convert dynamic to double
  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Entity representing a single item in the cart.
class CartItemEntity {
  const CartItemEntity({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  /// Item ID from backend
  final int itemId;

  /// Item display name from backend
  final String itemName;

  /// Item quantity in cart
  final int quantity;

  /// Price per unit
  final double price;

  /// Total price for this item (quantity × price)
  final double total;

  /// Parse cart item from backend JSON
  factory CartItemEntity.fromJson(Map<String, dynamic> json) {
    final price = _asDouble(json['price']);
    final quantity = _asInt(json['quantity']);
    final total = _asDouble(json['total']);

    return CartItemEntity(
      itemId: _asInt(json['item_id']),
      itemName: (json['item_name'] as String?)?.trim() ?? '',
      quantity: quantity,
      price: price,
      total: total == 0 ? price * quantity : total,
    );
  }

  /// Helper to convert dynamic to int
  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Helper to convert dynamic to double
  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Entity for guest cart preview (before merge).
/// Shows what items will be merged into the user's cart.
class GuestCartPreviewEntity {
  const GuestCartPreviewEntity({
    required this.itemCount,
    required this.totalPrice,
    this.items = const [],
  });

  final int itemCount;
  final double totalPrice;
  final List<CartItemEntity> items;

  factory GuestCartPreviewEntity.empty() =>
      const GuestCartPreviewEntity(itemCount: 0, totalPrice: 0.0);
}
