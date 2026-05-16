import 'package:flutter/foundation.dart';

import '../../domain/entities/cart_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_remote_data_source.dart';

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl({
    required CartRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final CartRemoteDataSource _remoteDataSource;

  @override
  Future<int> getPublicCartItemCount({required String deviceId}) async {
    final response = await _remoteDataSource.getPublicCart(deviceId: deviceId);
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      return 0;
    }

    final items = data['items'];
    if (items is! List) {
      return 0;
    }

    return items.fold<int>(0, (sum, item) {
      if (item is! Map) {
        return sum;
      }

      final quantityRaw = item['quantity'];
      final quantity = quantityRaw is num
          ? quantityRaw.toInt()
          : int.tryParse(quantityRaw?.toString() ?? '') ?? 0;

      return sum + quantity;
    });
  }

  @override
  Future<int> getEndUserCartItemCount() async {
    final response = await _remoteDataSource.getEndUserCart();
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      return 0;
    }

    final totals = data['totals'];
    if (totals is! Map<String, dynamic>) {
      return 0;
    }

    final itemsCountRaw = totals['items_count'];
    if (itemsCountRaw is num) {
      return itemsCountRaw.toInt();
    }

    if (itemsCountRaw is String) {
      return int.tryParse(itemsCountRaw) ?? 0;
    }

    return 0;
  }

  @override
  Future<GuestCartPreviewEntity> previewGuestCart(String deviceId) async {
    final responseData = await _remoteDataSource.previewGuestCart(deviceId);
    
    // Response already checked for success in data source
    // Parse the cart from response
    try {
      final cart = CartEntity.fromJson(responseData);
      return GuestCartPreviewEntity(
        itemCount: cart.totalItems,
        totalPrice: cart.totalPrice,
        items: cart.items,
      );
    } catch (e) {
      debugPrint('Error parsing preview cart: $e');
      return GuestCartPreviewEntity.empty();
    }
  }

  @override
  Future<CartEntity> mergeGuestCart(String deviceId) async {
    final responseData = await _remoteDataSource.mergeGuestCart(deviceId);
    
    // Response already checked for success in data source
    // Parse the merged cart from response
    try {
      return CartEntity.fromJson(responseData);
    } catch (e) {
      debugPrint('Error parsing merged cart: $e');
      return CartEntity.empty();
    }
  }

  @override
  Future<AddToGuestCartResult> addItemToGuestCart({
    required String itemId,
    required int quantity,
    required String deviceId,
  }) async {
    try {
      final response = await _remoteDataSource.addToGuestCart(
        itemId: itemId,
        quantity: quantity,
        deviceId: deviceId,
      );

      if (!response.success) {
        final error = response.message ?? 'Failed to add item to cart';
        
        // Check if error is due to different store
        if (error.toLowerCase().contains('store') ||
            error.toLowerCase().contains('different')) {
          return AddToGuestCartResult.failure(
              'Your cart has items from another store');
        }
        
        return AddToGuestCartResult.failure(error);
      }

      return AddToGuestCartResult.success(
        message: response.data?.message ?? 'Added to cart',
        itemCount: response.data?.cart?.totalQuantity,
      );
    } catch (error) {
      return AddToGuestCartResult.failure(error.toString());
    }
  }

  @override
  Future<void> clearGuestCart({required String deviceId}) async {
    await _remoteDataSource.clearGuestCart(deviceId: deviceId);
  }
}
