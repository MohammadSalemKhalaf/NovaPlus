import 'package:flutter/foundation.dart';

import '../../domain/entities/sales_agent_portfolio_item_entity.dart';
import '../../domain/usecases/get_portfolio_usecase.dart';

/// State class for Sales Agent Portfolio
class SalesAgentPortfolioState {
  const SalesAgentPortfolioState({
    this.loading = false,
    this.items = const <SalesAgentPortfolioItemEntity>[],
    this.errorMessage,
  });

  final bool loading;
  final List<SalesAgentPortfolioItemEntity> items;
  final String? errorMessage;

  SalesAgentPortfolioState copyWith({
    bool? loading,
    List<SalesAgentPortfolioItemEntity>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesAgentPortfolioState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  int get pendingCount => items.where((item) => item.status == 'pending').length;
  int get activeCount => items.where((item) => item.status == 'active').length;
  int get expiredCount => items.where((item) => item.status == 'expired').length;
}

/// Cubit for managing Sales Agent Portfolio
class SalesAgentPortfolioCubit extends ChangeNotifier {
  SalesAgentPortfolioCubit({
    required GetPortfolioUseCase getPortfolioUseCase,
  }) : _getPortfolioUseCase = getPortfolioUseCase;

  final GetPortfolioUseCase _getPortfolioUseCase;

  SalesAgentPortfolioState _state = const SalesAgentPortfolioState();

  SalesAgentPortfolioState get state => _state;

  void _emit(SalesAgentPortfolioState state) {
    _state = state;
    notifyListeners();
  }

  /// Initializes the portfolio dashboard
  /// Fetches agents portfolio (owners and stores)
  Future<void> initialize() async {
    _emit(_state.copyWith(loading: true));

    try {
      final items = await _getPortfolioUseCase.call();
      _emit(
        _state.copyWith(
          loading: false,
          items: items,
          clearError: true,
        ),
      );
    } catch (e) {
      _emit(
        _state.copyWith(
          loading: false,
          errorMessage: _extractErrorMessage(e),
        ),
      );
    }
  }

  /// Refresh portfolio data
  Future<void> refresh() {
    return initialize();
  }

  /// Clear error message
  void clearError() {
    _emit(_state.copyWith(clearError: true));
  }

  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '').trim();
    }
    return 'Failed to load portfolio';
  }
}
