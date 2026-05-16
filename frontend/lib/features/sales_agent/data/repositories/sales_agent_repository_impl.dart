import '../../domain/entities/sales_agent_activation_code_entity.dart';
import '../../domain/entities/sales_agent_business_type_entity.dart';
import '../../domain/entities/sales_agent_onboarding_result_entity.dart';
import '../../domain/entities/sales_agent_profile_entity.dart';
import '../../domain/entities/sales_agent_redeem_result_entity.dart';
import '../../domain/entities/sales_agent_owner_entity.dart';
import '../../domain/entities/sales_agent_store_entity.dart';
import '../../domain/entities/sales_agent_portfolio_item_entity.dart';
import '../../domain/repositories/sales_agent_repository.dart';
import '../datasources/sales_agent_remote_data_source.dart';

class SalesAgentRepositoryImpl implements SalesAgentRepository {
  SalesAgentRepositoryImpl({
    required SalesAgentRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final SalesAgentRemoteDataSource _remoteDataSource;

  @override
  Future<SalesAgentProfileEntity> getMe() async {
    final payload = await _remoteDataSource.getMe();
    final data = payload['data'];
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};

    final user = map['user'];
    final userMap = user is Map
        ? Map<String, dynamic>.from(user)
        : map;

    final role = _resolveRole(userMap);

    return SalesAgentProfileEntity(
      id: (userMap['id'] as num?)?.toInt() ?? 0,
      name: (userMap['name'] as String?)?.trim() ?? '',
      email: (userMap['email'] as String?)?.trim() ?? '',
      role: role,
    );
  }

  @override
  Future<void> logout() {
    return _remoteDataSource.logout();
  }

  @override
  Future<List<SalesAgentBusinessTypeEntity>> getBusinessTypes() async {
    final rows = await _remoteDataSource.getBusinessTypes();

    return rows
        .map(
          (row) => SalesAgentBusinessTypeEntity(
            id: (row['id'] as num?)?.toInt() ?? 0,
            name: (row['name'] as String?)?.trim() ?? '',
            slug: (row['slug'] as String?)?.trim() ?? '',
          ),
        )
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  @override
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
  }) async {
    final data = await _remoteDataSource.onboardOwner(
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      password: password,
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      businessMode: businessMode,
      activationChannel: activationChannel,
      businessTypeId: businessTypeId,
      tenantWhatsappNumber: tenantWhatsappNumber,
    );

    final owner = data['owner'];
    final ownerMap = owner is Map
        ? Map<String, dynamic>.from(owner)
        : <String, dynamic>{};

    final tenant = data['tenant'];
    final tenantMap = tenant is Map
        ? Map<String, dynamic>.from(tenant)
        : <String, dynamic>{};

    final ownerUserId =
        (ownerMap['id'] as num?)?.toInt() ?? (data['owner_user_id'] as num?)?.toInt() ?? 0;
    final tenantId =
        (tenantMap['id'] as num?)?.toInt() ?? (data['tenant_id'] as num?)?.toInt() ?? 0;
    final email =
        (ownerMap['email'] as String?)?.trim() ?? (data['email'] as String?)?.trim() ?? '';

    return SalesAgentOnboardingResultEntity(
      ownerUserId: ownerUserId,
      tenantId: tenantId,
      email: email,
    );
  }

  @override
  Future<SalesAgentActivationCodeEntity> createActivationCode({
    required int durationMonths,
    String? code,
    String? note,
    required int soldByUserId,
  }) async {
    final data = await _remoteDataSource.createActivationCode(
      durationMonths: durationMonths,
      code: code,
      note: note,
      soldByUserId: soldByUserId,
    );

    final resolvedCode = (data['code'] as String?)?.trim() ?? '';

    return SalesAgentActivationCodeEntity(code: resolvedCode);
  }

  @override
  Future<SalesAgentActivationCodeEntity?> getLatestActiveCode() async {
    final data = await _remoteDataSource.getLatestActiveCode();
    final resolvedCode = (data['code'] as String?)?.trim() ?? '';

    if (resolvedCode.isEmpty) {
      return null;
    }

    return SalesAgentActivationCodeEntity(code: resolvedCode);
  }

  @override
  Future<SalesAgentRedeemResultEntity> redeemSubscription({
    required String code,
    required int tenantId,
  }) async {
    final data = await _remoteDataSource.redeemSubscription(
      code: code,
      tenantId: tenantId,
    );

    final status = (data['status'] as String?)?.trim() ?? '';

    return SalesAgentRedeemResultEntity(
      status: status,
      raw: data,
    );
  }

  @override
  Future<void> updateProfile({
    String? email,
    String? password,
  }) {
    return _remoteDataSource.updateProfile(
      email: email,
      password: password,
    );
  }

  @override
  Future<List<SalesAgentPortfolioItemEntity>> getPortfolio() async {
    // Fetch both owners and stores in parallel
    final ownerRows = await _remoteDataSource.getOwners();
    final storeRows = await _remoteDataSource.getStores();

    print('DEBUG: Raw owners response count: ${ownerRows.length}');
    print('DEBUG: Raw stores response count: ${storeRows.length}');

    // Parse owners
    final owners = ownerRows
        .map((row) {
          print('DEBUG: Parsing owner - id: ${row['id']}, name: ${row['name']}, created_by: ${row['created_by']}');
          return SalesAgentOwnerEntity(
            id: (row['id'] as num?)?.toInt() ?? 0,
            name: (row['name'] as String?)?.trim() ?? '',
            email: (row['email'] as String?)?.trim() ?? '',
            createdBy: (row['created_by'] as num?)?.toInt(),
          );
        })
        .where((item) => item.id > 0)
        .toList();

    print('DEBUG: Parsed owners count: ${owners.length}');

    // Parse stores
    final stores = storeRows
        .map((row) {
          final expiryDate = row['expires_at'];
          DateTime? expiresAt;
          if (expiryDate is String && expiryDate.isNotEmpty) {
            try {
              expiresAt = DateTime.parse(expiryDate);
            } catch (_) {}
          }

          final ownerRaw = row['owner'];
          final ownerMap = ownerRaw is Map
              ? Map<String, dynamic>.from(ownerRaw)
              : const <String, dynamic>{};

          final tenantId =
              (row['tenant_id'] as num?)?.toInt() ??
              (row['id'] as num?)?.toInt() ??
              0;

          final ownerId =
              (row['owner_id'] as num?)?.toInt() ??
              (row['owner_user_id'] as num?)?.toInt() ??
              (ownerMap['id'] as num?)?.toInt() ??
              0;

          print('DEBUG: Parsing store - id: ${row['id']}, tenant_id: $tenantId, owner_id: $ownerId, status: ${row['status']}');

          return SalesAgentStoreEntity(
            id: (row['id'] as num?)?.toInt() ?? 0,
            tenantId: tenantId,
            name: (row['name'] as String?)?.trim() ?? '',
            slug: (row['slug'] as String?)?.trim() ?? '',
            ownerId: ownerId,
            status: (row['status'] as String?)?.trim().toLowerCase() ?? 'pending',
            expiresAt: expiresAt,
            createdBy: (row['created_by'] as num?)?.toInt(),
          );
        })
        .where((item) {
          final isValid = item.id > 0 && item.tenantId > 0 && item.ownerId > 0;
          if (!isValid) {
            print('DEBUG: Filtering out invalid store - id: ${item.id}, tenant_id: ${item.tenantId}, owner_id: ${item.ownerId}');
          }
          return isValid;
        })
        .toList();

    print('DEBUG: Parsed stores count: ${stores.length}');

    // Create a map for fast owner lookup
    final ownerMap = {for (var owner in owners) owner.id: owner};
    print('DEBUG: Owner map keys: ${ownerMap.keys.toList()}');

    // Combine owners and stores
    final portfolio = stores
        .map((store) {
          final owner = ownerMap[store.ownerId];
          if (owner == null) {
            print('DEBUG: Store ${store.id} has owner_id ${store.ownerId} but no matching owner found!');
            return null;
          }
          print('DEBUG: Successfully merged store ${store.id} with owner ${owner.id}');
          return SalesAgentPortfolioItemEntity(
            owner: owner,
            store: store,
          );
        })
        .whereType<SalesAgentPortfolioItemEntity>()
        .toList();

    print('DEBUG: FINAL PORTFOLIO COUNT: ${portfolio.length}');
    return portfolio;
  }

  String _resolveRole(Map<String, dynamic> userMap) {
    final roles = userMap['roles'];
    if (roles is List && roles.isNotEmpty) {
      final first = roles.first.toString().trim().toLowerCase();
      if (first == 'sales_agent') {
        return 'sales_agent';
      }
      return first;
    }

    final role = (userMap['role'] as String?)?.trim().toLowerCase();
    if (role != null && role.isNotEmpty) {
      return role;
    }

    return 'guest';
  }
}
