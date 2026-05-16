import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../items/domain/entities/item_entity.dart';
import '../../../items/domain/repositories/items_repository.dart';
import '../../../offers/domain/entities/offer_entity.dart';
import '../../../offers/domain/repositories/offers_repository.dart';

class OwnerCatalogController extends ChangeNotifier {
  OwnerCatalogController({
    required ItemsRepository itemsRepository,
    required CategoriesRepository categoriesRepository,
    required OffersRepository offersRepository,
  }) : _itemsRepository = itemsRepository,
      _categoriesRepository = categoriesRepository,
      _offersRepository = offersRepository;

  final ItemsRepository _itemsRepository;
  final CategoriesRepository _categoriesRepository;
  final OffersRepository _offersRepository;

  bool _isLoading = true;
  bool _isUnauthorized = false;
  String? _errorMessage;
  List<ItemEntity> _items = const <ItemEntity>[];
  List<CategoryEntity> _categories = const <CategoryEntity>[];
  List<OfferEntity> _offers = const <OfferEntity>[];
  final Set<int> _deleteInProgress = <int>{};
  final Set<int> _selectedItemIds = <int>{};
  int? _selectedCategoryId;
  String _searchQuery = '';
  String? _actionMessage;
  bool _isActionError = false;
  bool _isApplyingOffer = false;

  bool get isLoading => _isLoading;
  bool get isUnauthorized => _isUnauthorized;
  String? get errorMessage => _errorMessage;
  List<ItemEntity> get items => _items;
  List<CategoryEntity> get categories => _categories;
  List<OfferEntity> get offers => _offers;
  Set<int> get selectedItemIds => _selectedItemIds;
  int get selectedItemsCount => _selectedItemIds.length;
  bool get hasSelectedItems => _selectedItemIds.isNotEmpty;
  bool get isApplyingOffer => _isApplyingOffer;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isActionError => _isActionError;

  bool isDeleteInProgress(int itemId) => _deleteInProgress.contains(itemId);

  String? consumeActionMessage() {
    final message = _actionMessage;
    _actionMessage = null;
    _isActionError = false;
    return message;
  }

  List<ItemEntity> get filteredItems {
    Iterable<ItemEntity> current = _items;

    if (_selectedCategoryId != null) {
      current = current.where((item) => item.categoryId == _selectedCategoryId);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      current = current.where((item) {
        final name = item.name.toLowerCase();
        final description =
            ((item.shortDescription ?? item.description ?? '')).toLowerCase();
        return name.contains(query) || description.contains(query);
      });
    }

    return current.toList(growable: false);
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _isUnauthorized = false;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _itemsRepository.getItems(),
        _categoriesRepository.getCategories(),
        _offersRepository.getOffers(status: 'active', perPage: 100),
      ]);

      _items = results[0] as List<ItemEntity>;
      _categories = results[1] as List<CategoryEntity>;
      _offers = results[2] as List<OfferEntity>;
      _selectedItemIds.removeWhere(
        (itemId) => !_items.any((item) => item.id == itemId),
      );
      debugPrint('ITEMS COUNT: ${_items.length}');
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } on DioException catch (error) {
      debugPrint('CATALOG ERROR (dio): ${error.message}');
      debugPrint('CATALOG ERROR RESPONSE: ${error.response?.data}');
      _isLoading = false;
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      } else {
        _errorMessage = 'Something went wrong';
      }
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('CATALOG ERROR: $error');
      debugPrint('CATALOG STACK: $stackTrace');
      _isLoading = false;
      _errorMessage = 'Something went wrong';
      notifyListeners();
    }
  }

  Future<void> deleteItem(ItemEntity item) async {
    try {
      _deleteInProgress.add(item.id);
      notifyListeners();

      await _itemsRepository.deleteItem(item.id);

      await _reloadItemsOnly();
      _actionMessage = 'Item deleted successfully';
      _isActionError = false;
      notifyListeners();
    } on DioException catch (error) {
      debugPrint('DELETE ITEM ERROR (dio): ${error.message}');
      debugPrint('DELETE ITEM ERROR RESPONSE: ${error.response?.data}');

      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      }

      _actionMessage = 'Failed to delete item';
      _isActionError = true;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('DELETE ITEM ERROR: $error');
      debugPrint('DELETE ITEM STACK: $stackTrace');
      _actionMessage = 'Failed to delete item';
      _isActionError = true;
      notifyListeners();
    } finally {
      _deleteInProgress.remove(item.id);
      notifyListeners();
    }
  }

  Future<void> _reloadItemsOnly() async {
    final latestItems = await _itemsRepository.getItems();
    _items = latestItems;
    _selectedItemIds.removeWhere(
      (itemId) => !_items.any((item) => item.id == itemId),
    );
  }

  bool isItemSelected(int itemId) => _selectedItemIds.contains(itemId);

  void toggleItemSelection(int itemId) {
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    notifyListeners();
  }

  void clearSelectedItems() {
    if (_selectedItemIds.isEmpty) {
      return;
    }

    _selectedItemIds.clear();
    notifyListeners();
  }

  Future<void> applyOfferToSelectedItems(int offerId) async {
    if (_selectedItemIds.isEmpty || _isApplyingOffer) {
      return;
    }

    try {
      _isApplyingOffer = true;
      notifyListeners();

      OfferEntity? selectedOffer;
      for (final offer in _offers) {
        if (offer.id == offerId) {
          selectedOffer = offer;
          break;
        }
      }

      if (selectedOffer == null) {
        throw Exception('Offer not found');
      }

      final mergedItemIds = <int>{
        ...selectedOffer.itemIds,
        ..._selectedItemIds,
      }.toList(growable: false);

      await _offersRepository.updateOffer(
        id: offerId,
        itemIds: mergedItemIds,
      );

      await load();
      _selectedItemIds.clear();
      _actionMessage = 'Offer applied to selected items';
      _isActionError = false;
      notifyListeners();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      }
      _actionMessage = 'Failed to apply offer';
      _isActionError = true;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('APPLY OFFER ERROR: $error');
      debugPrint('APPLY OFFER STACK: $stackTrace');
      _actionMessage = 'Failed to apply offer';
      _isActionError = true;
      notifyListeners();
    } finally {
      _isApplyingOffer = false;
      notifyListeners();
    }
  }

  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearUnauthorized() {
    _isUnauthorized = false;
    notifyListeners();
  }
}
