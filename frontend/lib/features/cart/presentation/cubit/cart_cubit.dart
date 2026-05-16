import 'package:flutter/foundation.dart';

import '../../data/cart_api_service.dart';
import '../../data/cart_repository.dart';
import '../../data/device_service.dart';
import '../../domain/entities/cart_entity.dart';

abstract class CartStateData {
  const CartStateData();
}

class CartInitial extends CartStateData {
  const CartInitial();
}

class CartLoading extends CartStateData {
  const CartLoading();
}

class CartLoaded extends CartStateData {
  const CartLoaded({required this.cart});

  final CartEntity cart;
}

class CartError extends CartStateData {
  const CartError({required this.message});

  final String message;
}

class CartCubit extends ChangeNotifier {
  CartCubit({required DeviceService deviceService})
    : _repository = CartRepository(
        apiService: CartApiService(),
        deviceService: deviceService,
      );
  final Map<int, String> _itemImageById = <int, String>{};
  final Map<int, String> _itemNameById = <int, String>{};
  final Set<int> _imageRequestsInFlight = <int>{};

  final CartRepository _repository;
  int? _currentStoreId;
  String? _storeSwitchMessage;

  CartStateData _state = const CartInitial();
  CartStateData get state => _state;

  bool get isLoading => _state is CartLoading;
  int get totalItems => _cart?.totalItems ?? 0;
  double get totalPrice => _cart?.totalPrice ?? 0.0;
  List<CartItemEntity> get items => _cart?.items ?? const <CartItemEntity>[];
  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);
  String? get errorMessage =>
      _state is CartError ? (_state as CartError).message : null;
  int? get currentStoreId => _currentStoreId;
  String? get storeSwitchMessage => _storeSwitchMessage;
  CartEntity? get _cart =>
      _state is CartLoaded ? (_state as CartLoaded).cart : null;
  String? imageForItem(int itemId) => _itemImageById[itemId];
  String? nameForItem(int itemId) => _itemNameById[itemId];

  /// Alias for compatibility
  int get itemCount => totalItems;

  void clearStoreSwitchMessage() {
    _storeSwitchMessage = null;
  }

  void clearLocalCart() {
    _setState(CartLoaded(cart: CartEntity.empty()));
    _itemImageById.clear();
    _itemNameById.clear();
    _imageRequestsInFlight.clear();
  }

  Future<void> onEnterStore(int storeId) async {
    if (_currentStoreId != null && _currentStoreId != storeId) {
      clearLocalCart();
      _storeSwitchMessage = 'Cart cleared because you switched stores';
      notifyListeners();
    }
    _currentStoreId = storeId;
    await fetchCart(storeId: storeId);
  }

  void _setState(CartStateData state) {
    _state = state;
    notifyListeners();
  }

  Future<void> getCart({required int storeId, bool silent = false}) async {
    _currentStoreId = storeId;
    final previousState = _state;
    if (!silent || _state is! CartLoaded) {
      _setState(const CartLoading());
    }
    try {
      final cart = await _repository.getCart(storeId: storeId);
      _setState(CartLoaded(cart: cart));
      _hydrateCartItemImages(cart: cart, storeId: storeId);
    } catch (error) {
      if (silent && previousState is CartLoaded) {
        _setState(previousState);
        return;
      }
      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> getEndUserCart({bool silent = false}) async {
    final previousState = _state;
    if (!silent || _state is! CartLoaded) {
      _setState(const CartLoading());
    }

    try {
      final cart = await _repository.getEndUserCart();
      _setState(CartLoaded(cart: cart));
    } catch (error) {
      if (silent && previousState is CartLoaded) {
        _setState(previousState);
        return;
      }

      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> getEndUserCartForStore({
    required int storeId,
    bool silent = false,
  }) async {
    _currentStoreId = storeId;
    final previousState = _state;
    if (!silent || _state is! CartLoaded) {
      _setState(const CartLoading());
    }

    try {
      final cart = await _repository.getEndUserCartForTenant(tenantId: storeId);
      _setState(CartLoaded(cart: cart));
      _hydrateCartItemImages(cart: cart, storeId: storeId);
    } catch (error) {
      if (silent && previousState is CartLoaded) {
        _setState(previousState);
        return;
      }

      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> _hydrateCartItemImages({
    required CartEntity cart,
    required int storeId,
  }) async {
    if (cart.items.isEmpty) {
      return;
    }

    var changed = false;
    for (final item in cart.items) {
      final itemId = item.itemId;
      if (itemId <= 0 || _itemImageById.containsKey(itemId)) {
        continue;
      }
      if (_imageRequestsInFlight.contains(itemId)) {
        continue;
      }

      _imageRequestsInFlight.add(itemId);
      try {
        final meta = await _repository.getCartItemMeta(
          storeId: storeId,
          itemId: itemId,
        );
        if (meta.imagePath != null && meta.imagePath!.isNotEmpty) {
          _itemImageById[itemId] = meta.imagePath!;
          changed = true;
        }
        if (meta.name != null && meta.name!.isNotEmpty) {
          _itemNameById[itemId] = meta.name!;
          changed = true;
        }
      } catch (_) {
        // Image is optional; ignore failures to keep cart responsive.
      } finally {
        _imageRequestsInFlight.remove(itemId);
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> addItem({
    required int itemId,
    int quantity = 1,
    required int storeId,
  }) async {
    _setState(const CartLoading());
    try {
      if (_currentStoreId != null && _currentStoreId != storeId) {
        await _repository.clearCart(storeId: _currentStoreId!);
        _storeSwitchMessage = 'Cart cleared because you switched stores';
      }

      _currentStoreId = storeId;
      await _repository.addItem(
        storeId: storeId,
        itemId: itemId,
        quantity: quantity,
      );
      await fetchCart(storeId: storeId);
    } catch (error) {
      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> removeItem({required int itemId, int? storeId}) async {
    final resolvedStoreId = storeId ?? _currentStoreId;
    if (resolvedStoreId == null) {
      clearLocalCart();
      return;
    }

    _setState(const CartLoading());
    try {
      _currentStoreId = resolvedStoreId;
      await _repository.removeItem(storeId: resolvedStoreId, itemId: itemId);
      await fetchCart(storeId: resolvedStoreId);
    } catch (error) {
      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> incrementItem({required int itemId, int? storeId}) async {
    final resolvedStoreId = storeId ?? _currentStoreId;
    if (resolvedStoreId == null) {
      return;
    }

    try {
      _currentStoreId = resolvedStoreId;
      await _repository.incrementItem(storeId: resolvedStoreId, itemId: itemId);
      await fetchCart(storeId: resolvedStoreId, silent: true);
    } catch (_) {
      // Keep current UI stable; quantity refresh will retry on next fetch.
    }
  }

  Future<void> decrementItem({required int itemId, int? storeId}) async {
    final resolvedStoreId = storeId ?? _currentStoreId;
    if (resolvedStoreId == null) {
      return;
    }

    try {
      _currentStoreId = resolvedStoreId;
      await _repository.decrementItem(storeId: resolvedStoreId, itemId: itemId);
      await fetchCart(storeId: resolvedStoreId, silent: true);
    } catch (_) {
      // Keep current UI stable; quantity refresh will retry on next fetch.
    }
  }

  Future<void> clearCart({int? storeId}) async {
    final resolvedStoreId = storeId ?? _currentStoreId;
    if (resolvedStoreId == null) {
      clearLocalCart();
      return;
    }

    _setState(const CartLoading());
    try {
      _currentStoreId = resolvedStoreId;
      await _repository.clearCart(storeId: resolvedStoreId);
      await fetchCart(storeId: resolvedStoreId);
    } catch (error) {
      _setState(CartError(message: error.toString()));
    }
  }

  Future<void> fetchCart({int? storeId, bool silent = false}) async {
    final resolvedStoreId = storeId ?? _currentStoreId;
    if (resolvedStoreId == null) {
      clearLocalCart();
      return;
    }
    await getCart(storeId: resolvedStoreId, silent: silent);
  }

  Future<String?> checkoutWhatsApp() async {
    final resolvedStoreId = _currentStoreId;
    if (resolvedStoreId == null) {
      return null;
    }

    _setState(const CartLoading());
    try {
      final url = await _repository.checkoutWhatsApp(storeId: resolvedStoreId);
      await fetchCart(storeId: resolvedStoreId);
      return url;
    } catch (error) {
      _setState(CartError(message: error.toString()));
      return null;
    }
  }
}
