import '../../domain/entities/admin_dashboard_data_entity.dart';
import '../../domain/entities/admin_business_type_entity.dart';
import '../../domain/entities/admin_sales_agent_entity.dart';
import '../../domain/entities/admin_sales_agent_overview_entity.dart';
import '../../domain/entities/admin_report_filters.dart';
import '../../domain/entities/admin_report_models.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../datasources/admin_dashboard_remote_data_source.dart';

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  AdminDashboardRepositoryImpl({
    required AdminDashboardRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final AdminDashboardRemoteDataSource _remoteDataSource;

  @override
  Future<AdminDashboardDataEntity> getDashboardData() async {
    final stores = await _fetchAllStores();
    final subscriptions = await _fetchAllSubscriptions();
    final businessTypeNameById = await _fetchBusinessTypeNameById();

    final activeSnapshot = await _remoteDataSource
        .getActiveSubscriptionsSnapshot();
    final activeSubscriptions =
        _readActiveSubscriptionsCount(activeSnapshot) ??
        _fallbackActiveSubscriptionsCount(subscriptions);

    double revenue = 0;
    try {
      final revenueSnapshot = await _remoteDataSource.getRevenueDashboard();
      revenue = _readRevenue(revenueSnapshot);
    } catch (_) {
      revenue = 0;
    }

    var distribution = _buildBusinessTypeDistribution(
      stores,
      businessTypeNameById,
    );
    if (distribution.isEmpty && businessTypeNameById.isNotEmpty) {
      distribution = businessTypeNameById.values
          .map(
            (name) => BusinessTypeDistributionEntity(
              name: name,
              count: 0,
            ),
          )
          .toList(growable: false);
    }
    final ownerDateById = _extractOwnerFirstSeenDates(subscriptions);
    final storeEventDates = _extractStoreEventDates(subscriptions);

    final weeklyStores = _buildDailySeries(storeEventDates, 7);
    final weeklyOwners = _buildDailySeries(ownerDateById.values.toList(), 7);
    final monthlyStores = _compressSeriesToSeven(
      _buildDailySeries(storeEventDates, 30),
    );
    final monthlyOwners = _compressSeriesToSeven(
      _buildDailySeries(ownerDateById.values.toList(), 30),
    );

    return AdminDashboardDataEntity(
      totalStores: stores.length,
      totalOwners: ownerDateById.length,
      activeSubscriptions: activeSubscriptions,
      revenue: revenue,
      weeklyStoresActivity: weeklyStores,
      weeklyOwnersActivity: weeklyOwners,
      monthlyStoresActivity: monthlyStores,
      monthlyOwnersActivity: monthlyOwners,
      businessTypeDistribution: distribution,
    );
  }

  @override
  Future<List<AdminBusinessTypeEntity>> getBusinessTypes() async {
    final response = await _remoteDataSource.getBusinessTypes();
    return response
        .map(
          (item) => AdminBusinessTypeEntity(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: (item['name'] as String?) ?? '',
            slug: (item['slug'] as String?) ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<StoreModel>> getStores(StoresFilter filter) async {
    final query = filter.toQuery();
    print('Stores filter query: $query');

    final payload = await _remoteDataSource.getStores(
      page: filter.page,
      perPage: filter.perPage,
      queryParameters: query,
    );

    final data = payload['data'];
    final list = <Map<String, dynamic>>[];
    if (data is List) {
      list.addAll(data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
    } else if (data is Map) {
      final tenants = data['tenants'];
      if (tenants is List) {
        list.addAll(
          tenants.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
        );
      }
    }

    var stores = list
        .map(StoreModel.fromJson)
        .where((store) => store.id > 0)
        .toList(growable: false);

    // Safe fallback in case backend ignores business_type_id filtering.
    if (filter.businessTypeId != null) {
      stores = stores
          .where((store) => store.businessTypeId == filter.businessTypeId)
          .toList(growable: false);
    }

    return stores;
  }

  @override
  Future<List<Map<String, dynamic>>> getSubscriptions(SubscriptionFilter filter) async {
    final payload = await _remoteDataSource.getSubscriptions(
      page: filter.page,
      perPage: filter.perPage,
      queryParameters: filter.toQuery(),
    );

    final data = payload['data'];
    if (data is! Map) {
      return const <Map<String, dynamic>>[];
    }

    final subscriptions = data['subscriptions'];
    if (subscriptions is! List) {
      return const <Map<String, dynamic>>[];
    }

    return subscriptions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  Future<List<SalesAgentModel>> getAgentReport(UsersFilter filter) async {
    final payload = await _remoteDataSource.getCreatedOwnersReport(
      salesAgentId: filter.agentId,
      perPage: filter.perPage,
    );

    final data = payload['data'];
    if (data is! Map) {
      return const <SalesAgentModel>[];
    }

    final salesAgents = data['sales_agents'];
    if (salesAgents is! List) {
      return const <SalesAgentModel>[];
    }

    return salesAgents
        .whereType<Map>()
        .map((item) => SalesAgentModel.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAllStores() async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    do {
      final payload = await _remoteDataSource.getStores(
        page: page,
        perPage: 20,
      );
      final data = payload['data'];
      if (data is Map) {
        final tenants = data['tenants'];
        if (tenants is List) {
          all.addAll(
            tenants
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false),
          );
        }

        final pagination = data['pagination'];
        if (pagination is Map) {
          lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
        }
      } else if (data is List) {
        all.addAll(
          data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false),
        );
      }

      final meta = payload['meta'];
      if (meta is Map) {
        final pagination = meta['pagination'];
        if (pagination is Map) {
          lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
        }
      }
      page += 1;
    } while (page <= lastPage);

    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchAllSubscriptions() async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    do {
      final payload = await _remoteDataSource.getSubscriptions(
        page: page,
        perPage: 100,
      );
      final data = payload['data'];
      if (data is Map) {
        final subscriptions = data['subscriptions'];
        if (subscriptions is List) {
          all.addAll(
            subscriptions
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false),
          );
        }

        final pagination = data['pagination'];
        if (pagination is Map) {
          lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
        }
      }

      page += 1;
    } while (page <= lastPage);

    return all;
  }

  int? _readActiveSubscriptionsCount(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map) {
      return null;
    }

    final pagination = data['pagination'];
    if (pagination is! Map) {
      return null;
    }

    return (pagination['total'] as num?)?.toInt();
  }

  int _fallbackActiveSubscriptionsCount(
    List<Map<String, dynamic>> subscriptions,
  ) {
    final now = DateTime.now();
    return subscriptions.where((item) {
      final status = (item['status'] as String?)?.toLowerCase() ?? '';
      final startsAt = DateTime.tryParse((item['starts_at'] as String?) ?? '');
      final endsAt = DateTime.tryParse((item['ends_at'] as String?) ?? '');
      return status == 'active' &&
          (startsAt == null || !startsAt.isAfter(now)) &&
          (endsAt == null || endsAt.isAfter(now));
    }).length;
  }

  double _readRevenue(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map) {
      return 0;
    }

    final metrics = data['metrics'];
    if (metrics is! Map) {
      return 0;
    }

    return (metrics['total_revenue'] as num?)?.toDouble() ?? 0;
  }

  List<BusinessTypeDistributionEntity> _buildBusinessTypeDistribution(
    List<Map<String, dynamic>> stores,
    Map<int, String> businessTypeNameById,
  ) {
    final counts = <String, int>{};
    for (final store in stores) {
      final rawBusinessType = store['business_type'];
      String? name;

      if (rawBusinessType is Map) {
        final businessType = Map<String, dynamic>.from(rawBusinessType);
        name = (businessType['name'] as String?)?.trim();
      }

      name ??= (store['business_type_name'] as String?)?.trim();

      final rawBusinessTypeId = store['business_type_id'];
      final businessTypeId = rawBusinessTypeId is num
          ? rawBusinessTypeId.toInt()
          : int.tryParse(rawBusinessTypeId?.toString() ?? '') ?? 0;

      if ((name == null || name.isEmpty) && businessTypeId > 0) {
        name = businessTypeNameById[businessTypeId];
      }

      if ((name == null || name.isEmpty) && businessTypeId > 0) {
        name = 'Type #$businessTypeId';
      }

      if (name == null || name.isEmpty) {
        name = 'Uncategorized';
      }
      counts[name] = (counts[name] ?? 0) + 1;
    }

    return counts.entries
        .map(
          (entry) => BusinessTypeDistributionEntity(
            name: entry.key,
            count: entry.value,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  Future<Map<int, String>> _fetchBusinessTypeNameById() async {
    try {
      final items = await getBusinessTypes();
      final map = <int, String>{};
      for (final item in items) {
        final name = item.name.trim();
        if (item.id > 0 && name.isNotEmpty) {
          map[item.id] = name;
        }
      }
      return map;
    } catch (_) {
      return const <int, String>{};
    }
  }

  Map<int, DateTime> _extractOwnerFirstSeenDates(
    List<Map<String, dynamic>> subscriptions,
  ) {
    final result = <int, DateTime>{};
    for (final subscription in subscriptions) {
      final createdAt = DateTime.tryParse(
        (subscription['created_at'] as String?) ?? '',
      );
      if (createdAt == null) {
        continue;
      }

      final tenantRaw = subscription['tenant'];
      if (tenantRaw is! Map) {
        continue;
      }
      final tenant = Map<String, dynamic>.from(tenantRaw);
      final ownerId = (tenant['owner_user_id'] as num?)?.toInt();
      if (ownerId == null) {
        continue;
      }

      final current = result[ownerId];
      if (current == null || createdAt.isBefore(current)) {
        result[ownerId] = createdAt;
      }
    }

    return result;
  }

  List<DateTime> _extractStoreEventDates(
    List<Map<String, dynamic>> subscriptions,
  ) {
    return subscriptions
        .map((item) => DateTime.tryParse((item['created_at'] as String?) ?? ''))
        .whereType<DateTime>()
        .toList(growable: false);
  }

  List<int> _buildDailySeries(List<DateTime> dates, int days) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final buckets = List<int>.filled(days, 0);

    for (final date in dates) {
      final normalized = DateTime(date.year, date.month, date.day);
      if (normalized.isBefore(start)) {
        continue;
      }

      final diff = normalized.difference(start).inDays;
      if (diff >= 0 && diff < days) {
        buckets[diff] += 1;
      }
    }

    return buckets;
  }

  List<int> _compressSeriesToSeven(List<int> series) {
    if (series.length <= 7) {
      return series;
    }

    final result = List<int>.filled(7, 0);
    final chunk = series.length / 7;
    for (var i = 0; i < series.length; i++) {
      final bucket = (i / chunk).floor().clamp(0, 6);
      result[bucket] += series[i];
    }
    return result;
  }

  @override
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
  }) {
    return _remoteDataSource.onboardOwner(
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      password: password,
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      businessMode: businessMode,
      businessTypeId: businessTypeId,
      tenantWhatsappNumber: tenantWhatsappNumber,
      activationChannel: activationChannel,
    );
  }

  @override
  Future<Map<String, dynamic>> createActivationCode({
    required String code,
    required int durationMonths,
    String? note,
    int? soldByUserId,
    int? usageLimit,
    String? expiresAt,
  }) {
    return _remoteDataSource.createActivationCode(
      code: code,
      durationMonths: durationMonths,
      note: note,
      soldByUserId: soldByUserId,
      usageLimit: usageLimit,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<Map<String, dynamic>> redeemTenantOwner({
    required String code,
    required int tenantId,
  }) {
    return _remoteDataSource.redeemTenantOwner(code: code, tenantId: tenantId);
  }

  @override
  Future<Map<String, dynamic>> getCreatedOwnersReport({
    int? salesAgentId,
    int perPage = 20,
  }) async {
    final payload = await _remoteDataSource.getCreatedOwnersReport(
      salesAgentId: salesAgentId,
      perPage: perPage,
    );

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getRevenueByAgentReport({
    int? salesAgentId,
    String? createdFrom,
    String? createdTo,
  }) async {
    final payload = await _remoteDataSource.getRevenueByAgentReport(
      salesAgentId: salesAgentId,
      createdFrom: createdFrom,
      createdTo: createdTo,
    );

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getTopRevenueAgents({int limit = 10}) async {
    final payload = await _remoteDataSource.getTopRevenueAgents(limit: limit);

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getActiveSubscriptionsReport({
    int? createdByAgentId,
    int perPage = 20,
  }) async {
    final payload = await _remoteDataSource.getActiveSubscriptionsReport(
      createdByAgentId: createdByAgentId,
      perPage: perPage,
    );

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getExpiredSubscriptionsReport({
    int? createdByAgentId,
    int perPage = 20,
  }) async {
    final payload = await _remoteDataSource.getExpiredSubscriptionsReport(
      createdByAgentId: createdByAgentId,
      perPage: perPage,
    );

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getExpiringSoonSubscriptionsReport({
    int? createdByAgentId,
    int days = 7,
    int perPage = 20,
  }) async {
    final payload = await _remoteDataSource.getExpiringSoonSubscriptionsReport(
      createdByAgentId: createdByAgentId,
      days: days,
      perPage: perPage,
    );

    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const <String, dynamic>{};
  }

  @override
  Future<List<AdminSalesAgentOverviewEntity>> getSalesAgentsOverview({
    int perPage = 20,
  }) async {
    final payload = await _remoteDataSource.getSalesAgentsOverview(
      perPage: perPage,
    );

    final data = payload['data'];
    if (data is! Map) {
      return const <AdminSalesAgentOverviewEntity>[];
    }

    final rows = data['sales_agents'];
    if (rows is! List) {
      return const <AdminSalesAgentOverviewEntity>[];
    }

    return rows
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return AdminSalesAgentOverviewEntity(
            id: (map['id'] as num?)?.toInt() ?? 0,
            name: (map['name'] as String?) ?? '',
            email: (map['email'] as String?) ?? '',
            status: (map['status'] as String?) ?? 'unknown',
            ownersCount: (map['owners_count'] as num?)?.toInt() ?? 0,
            storesCount: (map['stores_count'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<AdminSalesAgentEntity>> getSalesAgents({
    int perPage = 20,
    String? status,
  }) async {
    final payload = await _remoteDataSource.getSalesAgents(
      perPage: perPage,
      status: status,
    );

    final data = payload['data'];
    if (data is! Map) {
      return const <AdminSalesAgentEntity>[];
    }

    final rows = data['sales_agents'];
    if (rows is! List) {
      return const <AdminSalesAgentEntity>[];
    }

    return rows
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final rolesRaw = map['roles'];
          final roles = rolesRaw is List
              ? rolesRaw
                    .whereType<Object>()
                    .map((role) => role.toString())
                    .toList(growable: false)
              : const <String>[];

          return AdminSalesAgentEntity(
            id: (map['id'] as num?)?.toInt() ?? 0,
            name: (map['name'] as String?) ?? '',
            email: (map['email'] as String?) ?? '',
            status: (map['status'] as String?) ?? 'unknown',
            roles: roles,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createSalesAgent({
    required String name,
    required String email,
    required String password,
  }) {
    return _remoteDataSource.createSalesAgent(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> updateSalesAgent({
    required int id,
    required String name,
    required String email,
    String? password,
  }) {
    return _remoteDataSource.updateSalesAgent(
      id: id,
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> updateSalesAgentStatus({
    required int id,
    required String status,
  }) {
    return _remoteDataSource.updateSalesAgentStatus(id: id, status: status);
  }

  @override
  Future<void> deleteSalesAgent({required int id}) {
    return _remoteDataSource.deleteSalesAgent(id: id);
  }
}
