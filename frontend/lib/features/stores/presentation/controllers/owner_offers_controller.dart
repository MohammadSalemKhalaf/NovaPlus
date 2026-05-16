import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../offers/domain/entities/offer_entity.dart';
import '../../../offers/domain/repositories/offers_repository.dart';

class OwnerOffersController extends ChangeNotifier {
  OwnerOffersController({required OffersRepository offersRepository})
    : _offersRepository = offersRepository;

  final OffersRepository _offersRepository;

  bool _isLoading = true;
  bool _isUnauthorized = false;
  String? _errorMessage;
  List<OfferEntity> _offers = const <OfferEntity>[];
  final Set<int> _deleteInProgress = <int>{};
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String? _actionMessage;
  bool _isActionError = false;

  bool get isLoading => _isLoading;
  bool get isUnauthorized => _isUnauthorized;
  String? get errorMessage => _errorMessage;
  List<OfferEntity> get offers => _offers;
  String get searchQuery => _searchQuery;
  String get selectedStatus => _selectedStatus;
  bool get isActionError => _isActionError;

  bool isDeleteInProgress(int offerId) => _deleteInProgress.contains(offerId);

  List<OfferEntity> get filteredOffers {
    Iterable<OfferEntity> current = _offers;

    final status = _selectedStatus.trim().toLowerCase();
    if (status.isNotEmpty && status != 'all') {
      current = current.where(
        (offer) => offer.status.trim().toLowerCase() == status,
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      current = current.where((offer) {
        final title = offer.title.toLowerCase();
        final description = (offer.description ?? '').toLowerCase();
        return title.contains(query) || description.contains(query);
      });
    }

    return current.toList(growable: false);
  }

  String? consumeActionMessage() {
    final message = _actionMessage;
    _actionMessage = null;
    _isActionError = false;
    return message;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _isUnauthorized = false;
    notifyListeners();

    try {
      _offers = await _offersRepository.getOffers(perPage: 100);
      _isLoading = false;
      notifyListeners();
    } on DioException catch (error) {
      _isLoading = false;
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      } else {
        _errorMessage = 'Something went wrong';
      }
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Something went wrong';
      notifyListeners();
    }
  }

  Future<void> deleteOffer(OfferEntity offer) async {
    try {
      _deleteInProgress.add(offer.id);
      notifyListeners();

      await _offersRepository.deleteOffer(offer.id);

      await _reloadOffersOnly();
      _actionMessage = 'Offer deleted successfully';
      _isActionError = false;
      notifyListeners();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      }
      _actionMessage = 'Failed to delete offer';
      _isActionError = true;
      notifyListeners();
    } catch (_) {
      _actionMessage = 'Failed to delete offer';
      _isActionError = true;
      notifyListeners();
    } finally {
      _deleteInProgress.remove(offer.id);
      notifyListeners();
    }
  }

  Future<void> _reloadOffersOnly() async {
    _offers = await _offersRepository.getOffers(perPage: 100);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void clearUnauthorized() {
    _isUnauthorized = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}