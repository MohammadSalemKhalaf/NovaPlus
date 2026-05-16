import '../entities/cart_entity.dart';

abstract class CartRepository {
  /// Get guest cart total quantity from backend.
  Future<int> getPublicCartItemCount({required String deviceId});

  /// Get authenticated end-user cart total quantity from backend.
  Future<int> getEndUserCartItemCount();

  /// Get a preview of the guest cart before merging.
  /// 
  /// Called after login but before merge to show what will be merged.
  /// Requires authentication token.
  Future<GuestCartPreviewEntity> previewGuestCart(String deviceId);

  /// Merge guest cart with authenticated user's cart.
  /// 
  /// Called immediately after successful login.
  /// Transfers all items from guest cart (identified by deviceId)
  /// to the authenticated user's cart.
  /// 
  /// After merge:
  /// - Stop using X-Device-ID header
  /// - Use authenticated endpoints only
  /// - Cart is now tied to user_id
  Future<CartEntity> mergeGuestCart(String deviceId);

  /// Add item to guest cart.
  /// 
  /// Called when guest user clicks "Add to Cart" on an item.
  /// Uses X-Device-ID header to track guest cart.
  /// 
  /// Returns success response or error (e.g., different store).
  Future<AddToGuestCartResult> addItemToGuestCart({
    required String itemId,
    required int quantity,
    required String deviceId,
  });

  /// Clear guest cart.
  /// 
  /// Called when user confirms clearing cart to add from different store.
  Future<void> clearGuestCart({required String deviceId});
}

/// Result of adding item to guest cart.
class AddToGuestCartResult {
  const AddToGuestCartResult({
    required this.success,
    this.message,
    this.error,
    this.itemCount,
  });

  final bool success;
  final String? message;
  final String? error;
  final int? itemCount;

  factory AddToGuestCartResult.success({String? message, int? itemCount}) {
    return AddToGuestCartResult(
      success: true,
      message: message ?? 'Added to cart',
      itemCount: itemCount,
    );
  }

  factory AddToGuestCartResult.failure(String error) {
    return AddToGuestCartResult(
      success: false,
      error: error,
    );
  }
}
