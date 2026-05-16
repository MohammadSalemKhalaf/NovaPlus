import '../entities/sales_agent_portfolio_item_entity.dart';
import '../repositories/sales_agent_repository.dart';

class GetPortfolioUseCase {
  GetPortfolioUseCase(this._repository);

  final SalesAgentRepository _repository;

  Future<List<SalesAgentPortfolioItemEntity>> call() {
    return _repository.getPortfolio();
  }
}
