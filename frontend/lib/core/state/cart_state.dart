import '../../features/cart/data/device_service.dart';
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../storage/secure_storage.dart';

class CartState extends CartCubit {
  CartState({required SecureStorage secureStorage})
    : _secureStorage = secureStorage,
      super(deviceService: DeviceService(secureStorage: secureStorage));

  final SecureStorage _secureStorage;

  bool _initialized = false;

  bool get initialized => _initialized;

  /// Initialize cart on app start
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await fetchCart();
  }

  /// Refresh cart count from backend
  Future<void> refreshCartCount() async {
    await fetchCart();
  }

  /// Called after add to cart success
  Future<void> onAddToCartSuccess({int? backendItemCount}) async {
    await fetchCart();
  }

  /// Fetch cart from backend - alias for getCart
  @override
  Future<void> fetchCart({int? storeId, bool silent = false}) async {
    if (await _secureStorage.isLoggedIn()) {
      final resolvedStoreId = storeId ?? currentStoreId;
      if (resolvedStoreId != null) {
        await getEndUserCartForStore(storeId: resolvedStoreId, silent: silent);
      } else {
        await getEndUserCart(silent: silent);
      }
      return;
    }

    final resolvedStoreId = storeId ?? currentStoreId;
    if (resolvedStoreId == null) {
      clearLocalCart();
      return;
    }

    await super.fetchCart(storeId: resolvedStoreId, silent: silent);
  }

  void clear() {
    clearLocalCart();
  }
}
