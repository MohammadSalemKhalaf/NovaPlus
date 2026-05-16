import '../domain/entities/cart_entity.dart';
import 'cart_api_service.dart';
import 'device_service.dart';

class CartRepository {
  CartRepository({
    required CartApiService apiService,
    required DeviceService deviceService,
  }) : _apiService = apiService,
       _deviceService = deviceService;

  final CartApiService _apiService;
  final DeviceService _deviceService;

  Future<CartEntity> getCart({required int storeId}) async {
    final deviceId = await _deviceService.getDeviceId();
    final payload = await _apiService.getCart(
      deviceId: deviceId,
      tenantId: storeId,
    );
    return _parseCart(payload);
  }

  Future<CartEntity> getEndUserCart() async {
    final payload = await _apiService.getEndUserCart();
    return _parseEndUserCart(payload);
  }

  Future<CartEntity> getEndUserCartForTenant({required int tenantId}) async {
    final payload = await _apiService.getEndUserCart();
    return _parseEndUserCart(payload, tenantId: tenantId);
  }

  Future<void> addItem({
    required int storeId,
    required int itemId,
    required int quantity,
  }) async {
    final deviceId = await _deviceService.getDeviceId();
    await _apiService.addItem(
      itemId: itemId,
      quantity: quantity,
      deviceId: deviceId,
      tenantId: storeId,
    );
  }

  Future<void> removeItem({required int storeId, required int itemId}) async {
    final deviceId = await _deviceService.getDeviceId();
    await _apiService.removeItem(
      itemId: itemId,
      deviceId: deviceId,
      tenantId: storeId,
    );
  }

  Future<void> incrementItem({
    required int storeId,
    required int itemId,
  }) async {
    final deviceId = await _deviceService.getDeviceId();
    await _apiService.incrementItem(
      itemId: itemId,
      deviceId: deviceId,
      tenantId: storeId,
    );
  }

  Future<void> decrementItem({
    required int storeId,
    required int itemId,
  }) async {
    final deviceId = await _deviceService.getDeviceId();
    await _apiService.decrementItem(
      itemId: itemId,
      deviceId: deviceId,
      tenantId: storeId,
    );
  }

  Future<void> clearCart({required int storeId}) async {
    final deviceId = await _deviceService.getDeviceId();
    await _apiService.clearCart(deviceId: deviceId, tenantId: storeId);
  }

  Future<String> checkoutWhatsApp({required int storeId}) async {
    final deviceId = await _deviceService.getDeviceId();
    final payload = await _apiService.checkoutWhatsApp(
      deviceId: deviceId,
      tenantId: storeId,
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final url = data['whatsapp_url']?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      final url = mapped['whatsapp_url']?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    throw Exception('WhatsApp URL is missing');
  }

  Future<CartItemMeta> getCartItemMeta({
    required int storeId,
    required int itemId,
  }) async {
    final payload = await _apiService.getPublicItemDetail(
      tenantId: storeId,
      itemId: itemId,
    );

    final data = payload['data'];
    final dataMap = data is Map<String, dynamic>
        ? data
        : data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};

    final itemName = dataMap['name']?.toString().trim();

    String? imagePath;
    final directImage = dataMap['image']?.toString().trim();
    if (directImage != null && directImage.isNotEmpty) {
      imagePath = directImage;
    }

    final primaryImage = dataMap['primary_image'];
    if (imagePath == null || imagePath.isEmpty) {
      if (primaryImage is Map<String, dynamic>) {
        final storagePath = primaryImage['storage_path']?.toString().trim();
        if (storagePath != null && storagePath.isNotEmpty) {
          imagePath = storagePath;
        }
      } else if (primaryImage is Map) {
        final mapped = Map<String, dynamic>.from(primaryImage);
        final storagePath = mapped['storage_path']?.toString().trim();
        if (storagePath != null && storagePath.isNotEmpty) {
          imagePath = storagePath;
        }
      }
    }

    return CartItemMeta(
      name: itemName != null && itemName.isNotEmpty ? itemName : null,
      imagePath: imagePath != null && imagePath.isNotEmpty ? imagePath : null,
    );
  }

  CartEntity _parseCart(Map<String, dynamic> payload) {
    try {
      return CartEntity.fromJson(payload);
    } catch (_) {
      return CartEntity.empty();
    }
  }

  CartEntity _parseEndUserCart(
    Map<String, dynamic> payload, {
    int? tenantId,
  }) {
    try {
      final data = payload['data'];
      final dataMap = data is Map<String, dynamic>
          ? data
          : data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};

      final itemsRaw = dataMap['items'];
      final itemsList = itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) {
                if (tenantId == null || tenantId <= 0) {
                  return true;
                }

                return _toInt(item['tenant_id']) == tenantId;
              })
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      final items = itemsList
          .map(
            (item) => CartItemEntity(
              itemId: _toInt(item['item_id']),
              itemName: (item['item_name'] as String?)?.trim() ?? '',
              quantity: _toInt(item['quantity']),
              price: _toDouble(item['unit_price_snapshot']),
              total: _toDouble(item['line_total']),
            ),
          )
          .toList(growable: false);

      final totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);
      final totalPrice = items.fold<double>(0.0, (sum, item) => sum + item.total);

      return CartEntity(
        totalItems: totalItems,
        totalPrice: totalPrice,
        items: items,
      );
    } catch (_) {
      return CartEntity.empty();
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class CartItemMeta {
  const CartItemMeta({
    this.name,
    this.imagePath,
  });

  final String? name;
  final String? imagePath;
}
