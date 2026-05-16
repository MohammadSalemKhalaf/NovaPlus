import 'package:flutter/foundation.dart';

import '../../../core/state/auth_state.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/favorites_repository.dart';
import '../domain/entities/favorite_entity.dart';

class FavoritesState {
  const FavoritesState({
    this.loading = false,
    this.success = false,
    this.error,
    this.isFavorite = false,
    this.favorites = const <FavoriteEntity>[],
    this.favoriteStatusByTenant = const <String, bool>{},
    this.statusCode,
  });

  final bool loading;
  final bool success;
  final String? error;
  final bool isFavorite;
  final List<FavoriteEntity> favorites;
  final Map<String, bool> favoriteStatusByTenant;
  final int? statusCode;
  List<String> get favoriteStoreIds =>
      favorites.map((item) => item.tenantId).toList(growable: false);

  FavoritesState copyWith({
    bool? loading,
    bool? success,
    String? error,
    bool clearError = false,
    bool? isFavorite,
    List<FavoriteEntity>? favorites,
    Map<String, bool>? favoriteStatusByTenant,
    int? statusCode,
    bool clearStatusCode = false,
  }) {
    return FavoritesState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      error: clearError ? null : (error ?? this.error),
      isFavorite: isFavorite ?? this.isFavorite,
      favorites: favorites ?? this.favorites,
      favoriteStatusByTenant:
          favoriteStatusByTenant ?? this.favoriteStatusByTenant,
      statusCode: clearStatusCode ? null : (statusCode ?? this.statusCode),
    );
  }
}

class FavoritesCubit extends ChangeNotifier {
  FavoritesCubit({
    required FavoritesRepository repository,
    required AuthState authState,
    SecureStorage? secureStorage,
  }) : _repository = repository,
       _authState = authState,
       _secureStorage = secureStorage ?? SecureStorage() {
    _hydrateLocalFavorites();
  }

  final FavoritesRepository _repository;
  final AuthState _authState;
  SecureStorage? _secureStorage;
  bool _disposed = false;

  SecureStorage get _storage {
    final current = _secureStorage;
    if (current != null) {
      return current;
    }

    final restored = SecureStorage();
    _secureStorage = restored;
    return restored;
  }

  FavoritesState _state = const FavoritesState();
  FavoritesState get state => _state;

  final Set<String> _inFlightChecks = <String>{};
  final Set<String> _inFlightToggles = <String>{};
  final Set<String> _localFavoriteStoreIds = <String>{};

  void _emit(FavoritesState value) {
    _state = value;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get _isGuestMode => _authState.isGuest || !_authState.isAuthenticated;

  FavoriteEntity _favoriteFromId(String tenantId) {
    return FavoriteEntity(tenantId: tenantId);
  }

  Future<void> _persistLocalFavorites() {
    return _storage.saveFavoriteStoreIds(
      _localFavoriteStoreIds.toList(growable: false),
    );
  }

  Future<void> _hydrateLocalFavorites() async {
    final stored = await _storage.getFavoriteStoreIds();
    _localFavoriteStoreIds
      ..clear()
      ..addAll(stored);

    if (_state.favorites.isNotEmpty ||
        _state.favoriteStatusByTenant.isNotEmpty) {
      return;
    }

    final localFavorites = _localFavoriteStoreIds
        .map(_favoriteFromId)
        .toList(growable: false);
    final localMap = <String, bool>{
      for (final id in _localFavoriteStoreIds) id: true,
    };

    _emit(
      _state.copyWith(
        favorites: localFavorites,
        favoriteStatusByTenant: localMap,
        clearError: true,
        clearStatusCode: true,
      ),
    );
  }

  Future<void> _loadLocalFavoritesToState() async {
    final stored = await _storage.getFavoriteStoreIds();
    _localFavoriteStoreIds
      ..clear()
      ..addAll(stored);

    final favorites = _localFavoriteStoreIds
        .map(_favoriteFromId)
        .toList(growable: false);
    final favoriteMap = <String, bool>{
      for (final id in _localFavoriteStoreIds) id: true,
    };

    _emit(
      _state.copyWith(
        loading: false,
        success: true,
        favorites: favorites,
        favoriteStatusByTenant: favoriteMap,
        clearError: true,
        clearStatusCode: true,
      ),
    );
  }

  bool isFavorite(String tenantId) {
    final id = tenantId.trim();
    if (id.isEmpty) {
      return false;
    }
    return _state.favoriteStoreIds.contains(id);
  }

  Future<void> loadFavorites() async {
    if (_isGuestMode) {
      await _loadLocalFavoritesToState();
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        success: false,
        clearError: true,
        clearStatusCode: true,
      ),
    );
    try {
      final remoteFavorites = await _repository.getFavorites();
      final mergedIds = <String>{
        ..._localFavoriteStoreIds,
        ...remoteFavorites.map((item) => item.tenantId),
      };
      _localFavoriteStoreIds
        ..clear()
        ..addAll(mergedIds);
      await _persistLocalFavorites();

      final favorites = mergedIds.map(_favoriteFromId).toList(growable: false);
      final favoriteMap = <String, bool>{for (final id in mergedIds) id: true};

      _emit(
        _state.copyWith(
          loading: false,
          success: true,
          favorites: favorites,
          favoriteStatusByTenant: favoriteMap,
          clearError: true,
          clearStatusCode: true,
        ),
      );
    } catch (error) {
      await _loadLocalFavoritesToState();
    }
  }

  Future<void> checkFavorite(String tenantId) async {
    if (tenantId.trim().isEmpty) {
      return;
    }

    if (_isGuestMode) {
      final isLocalFavorite = _localFavoriteStoreIds.contains(tenantId);
      final map = <String, bool>{
        ..._state.favoriteStatusByTenant,
        tenantId: isLocalFavorite,
      };
      _emit(
        _state.copyWith(
          isFavorite: isLocalFavorite,
          success: true,
          favoriteStatusByTenant: map,
          clearError: true,
          clearStatusCode: true,
        ),
      );
      return;
    }

    if (_state.favoriteStatusByTenant.containsKey(tenantId)) {
      final cached = _state.favoriteStatusByTenant[tenantId] ?? false;
      _emit(
        _state.copyWith(
          isFavorite: cached,
          success: true,
          clearError: true,
          clearStatusCode: true,
        ),
      );
      return;
    }

    if (_inFlightChecks.contains(tenantId)) {
      return;
    }

    _inFlightChecks.add(tenantId);
    _emit(
      _state.copyWith(
        loading: true,
        success: false,
        clearError: true,
        clearStatusCode: true,
      ),
    );

    try {
      final isFavorite = await _repository.checkFavorite(tenantId);
      final map = <String, bool>{
        ..._state.favoriteStatusByTenant,
        tenantId: isFavorite,
      };

      _emit(
        _state.copyWith(
          loading: false,
          success: true,
          isFavorite: isFavorite,
          favoriteStatusByTenant: map,
          clearError: true,
          clearStatusCode: true,
        ),
      );
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          success: false,
          error: 'Unable to check favorite status',
          statusCode: _repository.mapStatusCode(error),
        ),
      );
    } finally {
      _inFlightChecks.remove(tenantId);
    }
  }

  Future<void> toggleFavorite(String tenantId) async {
    if (tenantId.trim().isEmpty || _inFlightToggles.contains(tenantId)) {
      return;
    }

    if (_isGuestMode) {
      final currentlyFavorite = _localFavoriteStoreIds.contains(tenantId);
      if (currentlyFavorite) {
        _localFavoriteStoreIds.remove(tenantId);
      } else {
        _localFavoriteStoreIds.add(tenantId);
      }
      await _persistLocalFavorites();
      await _loadLocalFavoritesToState();
      return;
    }

    _inFlightToggles.add(tenantId);

    final currentlyFavorite = _state.favoriteStatusByTenant[tenantId] ?? false;
    final optimistic = !currentlyFavorite;
    final optimisticMap = <String, bool>{
      ..._state.favoriteStatusByTenant,
      tenantId: optimistic,
    };

    _emit(
      _state.copyWith(
        isFavorite: optimistic,
        favoriteStatusByTenant: optimisticMap,
        loading: true,
        success: false,
        clearError: true,
        clearStatusCode: true,
      ),
    );

    try {
      if (currentlyFavorite) {
        await _repository.removeFavorite(tenantId);
      } else {
        await _repository.addFavorite(tenantId);
      }

      await _refreshFavoriteListForTenant(tenantId, optimistic);
      await _persistLocalFavorites();

      _emit(
        _state.copyWith(
          loading: false,
          success: true,
          isFavorite: optimistic,
          clearError: true,
          clearStatusCode: true,
        ),
      );
    } catch (error) {
      final rollbackMap = <String, bool>{
        ..._state.favoriteStatusByTenant,
        tenantId: currentlyFavorite,
      };

      _emit(
        _state.copyWith(
          loading: false,
          success: false,
          isFavorite: currentlyFavorite,
          favoriteStatusByTenant: rollbackMap,
          error: 'Unable to update favorite',
          statusCode: _repository.mapStatusCode(error),
        ),
      );
    } finally {
      _inFlightToggles.remove(tenantId);
    }
  }

  Future<void> updateFavorite(String tenantId, bool notifications) async {
    if (_isGuestMode) {
      return;
    }

    if (tenantId.trim().isEmpty) {
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        success: false,
        clearError: true,
        clearStatusCode: true,
      ),
    );

    try {
      await _repository.updateFavorite(
        tenantId,
        notificationsOptIn: notifications,
      );
      await loadFavorites();
      _emit(
        _state.copyWith(
          loading: false,
          success: true,
          clearError: true,
          clearStatusCode: true,
        ),
      );
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          success: false,
          error: 'Unable to update favorite settings',
          statusCode: _repository.mapStatusCode(error),
        ),
      );
    }
  }

  Future<void> _refreshFavoriteListForTenant(
    String tenantId,
    bool isFavorite,
  ) async {
    final current = List<FavoriteEntity>.from(_state.favorites);
    final index = current.indexWhere((item) => item.tenantId == tenantId);

    if (isFavorite && index == -1) {
      current.add(FavoriteEntity(tenantId: tenantId));
    }

    if (!isFavorite && index != -1) {
      current.removeAt(index);
    }

    _localFavoriteStoreIds
      ..clear()
      ..addAll(current.map((item) => item.tenantId));

    final map = <String, bool>{for (final item in current) item.tenantId: true};
    _emit(_state.copyWith(favorites: current, favoriteStatusByTenant: map));
  }

  void clearError() {
    if (_state.error == null && _state.statusCode == null) {
      return;
    }

    _emit(_state.copyWith(clearError: true, clearStatusCode: true));
  }

  void clear() {
    _inFlightChecks.clear();
    _inFlightToggles.clear();
    final localFavorites = _localFavoriteStoreIds
        .map(_favoriteFromId)
        .toList(growable: false);
    final localMap = <String, bool>{
      for (final id in _localFavoriteStoreIds) id: true,
    };
    _emit(
      FavoritesState(
        favorites: localFavorites,
        favoriteStatusByTenant: localMap,
      ),
    );
  }
}
