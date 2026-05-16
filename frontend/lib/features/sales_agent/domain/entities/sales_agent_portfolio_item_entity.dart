import 'sales_agent_owner_entity.dart';
import 'sales_agent_store_entity.dart';

class SalesAgentPortfolioItemEntity {
  const SalesAgentPortfolioItemEntity({
    required this.owner,
    required this.store,
  });

  final SalesAgentOwnerEntity owner;
  final SalesAgentStoreEntity store;

  // Convenience getters
  String get storeName => store.name;
  String get ownerName => owner.name;
  String get status => store.status;
  DateTime? get expiresAt => store.expiresAt;
  int get tenantId => store.tenantId;
  int get ownerId => owner.id;
}
