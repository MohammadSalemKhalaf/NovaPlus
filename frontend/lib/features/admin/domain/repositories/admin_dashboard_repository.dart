import '../entities/admin_dashboard_data_entity.dart';
import '../entities/admin_business_type_entity.dart';
import '../entities/admin_sales_agent_entity.dart';
import '../entities/admin_sales_agent_overview_entity.dart';
import '../entities/admin_report_filters.dart';
import '../entities/admin_report_models.dart';

abstract class AdminDashboardRepository {
  Future<AdminDashboardDataEntity> getDashboardData();

  Future<List<AdminBusinessTypeEntity>> getBusinessTypes();

  Future<List<StoreModel>> getStores(StoresFilter filter);

  Future<List<Map<String, dynamic>>> getSubscriptions(SubscriptionFilter filter);

  Future<List<SalesAgentModel>> getAgentReport(UsersFilter filter);

  Future<Map<String, dynamic>> onboardOwner({
    required String ownerName,
    required String ownerEmail,
    required String password,
    required String tenantName,
    required String tenantSlug,
    required String businessMode,
    required int businessTypeId,
    String? tenantWhatsappNumber,
    required String activationChannel,
  });

  Future<Map<String, dynamic>> createActivationCode({
    required String code,
    required int durationMonths,
    String? note,
    int? soldByUserId,
    int? usageLimit,
    String? expiresAt,
  });

  Future<Map<String, dynamic>> redeemTenantOwner({
    required String code,
    required int tenantId,
  });

  Future<Map<String, dynamic>> getCreatedOwnersReport({
    int? salesAgentId,
    int perPage,
  });

  Future<Map<String, dynamic>> getRevenueByAgentReport({
    int? salesAgentId,
    String? createdFrom,
    String? createdTo,
  });

  Future<Map<String, dynamic>> getTopRevenueAgents({int limit});

  Future<Map<String, dynamic>> getActiveSubscriptionsReport({
    int? createdByAgentId,
    int perPage,
  });

  Future<Map<String, dynamic>> getExpiredSubscriptionsReport({
    int? createdByAgentId,
    int perPage,
  });

  Future<Map<String, dynamic>> getExpiringSoonSubscriptionsReport({
    int? createdByAgentId,
    int days,
    int perPage,
  });

  Future<List<AdminSalesAgentOverviewEntity>> getSalesAgentsOverview({
    int perPage,
  });

  Future<List<AdminSalesAgentEntity>> getSalesAgents({
    int perPage,
    String? status,
  });

  Future<void> createSalesAgent({
    required String name,
    required String email,
    required String password,
  });

  Future<void> updateSalesAgent({
    required int id,
    required String name,
    required String email,
    String? password,
  });

  Future<void> updateSalesAgentStatus({
    required int id,
    required String status,
  });

  Future<void> deleteSalesAgent({required int id});
}
