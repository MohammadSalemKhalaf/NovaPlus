import '../entities/sales_agent_activation_code_entity.dart';
import '../entities/sales_agent_business_type_entity.dart';
import '../entities/sales_agent_onboarding_result_entity.dart';
import '../entities/sales_agent_profile_entity.dart';
import '../entities/sales_agent_redeem_result_entity.dart';
import '../entities/sales_agent_portfolio_item_entity.dart';

abstract class SalesAgentRepository {
  Future<SalesAgentProfileEntity> getMe();

  Future<void> logout();

  Future<List<SalesAgentBusinessTypeEntity>> getBusinessTypes();

  Future<SalesAgentOnboardingResultEntity> onboardOwner({
    required String ownerName,
    required String ownerEmail,
    required String password,
    required String tenantName,
    required String tenantSlug,
    required String businessMode,
    required String activationChannel,
    required int businessTypeId,
    required String tenantWhatsappNumber,
  });

  Future<SalesAgentActivationCodeEntity> createActivationCode({
    required int durationMonths,
    String? code,
    String? note,
    required int soldByUserId,
  });

  Future<SalesAgentActivationCodeEntity?> getLatestActiveCode();

  Future<SalesAgentRedeemResultEntity> redeemSubscription({
    required String code,
    required int tenantId,
  });

  Future<void> updateProfile({
    String? email,
    String? password,
  });

  Future<List<SalesAgentPortfolioItemEntity>> getPortfolio();
}
