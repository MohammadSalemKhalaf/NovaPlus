import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';

class AdminDashboardRemoteDataSource {
  AdminDashboardRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static final Options _adminOptions = Options(
    headers: <String, dynamic>{'X-Skip-Tenant-ID': 'true'},
  );

  Future<Map<String, dynamic>> getStores({
    int page = 1,
    int perPage = 20,
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = <String, dynamic>{'page': page, 'per_page': perPage};
    if (queryParameters != null) {
      query.addAll(queryParameters);
    }
    query.removeWhere(
      (key, value) => value == null || (value is String && value.trim().isEmpty),
    );

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/tenants',
      queryParameters: query,
      options: _adminOptions,
    );

    print(response.data);

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSubscriptions({
    int page = 1,
    int perPage = 100,
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = <String, dynamic>{'page': page, 'per_page': perPage};
    if (queryParameters != null) {
      query.addAll(queryParameters);
    }
    query.removeWhere(
      (key, value) => value == null || (value is String && value.trim().isEmpty),
    );

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions-management',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getActiveSubscriptionsSnapshot() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions-management/active',
      queryParameters: const <String, dynamic>{'page': 1, 'per_page': 1},
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRevenueDashboard() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/revenue/dashboard',
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSalesAgentsOverview({
    int perPage = 20,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/sales-agents/reports/created-owners',
      queryParameters: <String, dynamic>{'per_page': perPage},
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSalesAgents({
    int perPage = 20,
    String? status,
  }) async {
    final query = <String, dynamic>{'per_page': perPage};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/sales-agents',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<void> createSalesAgent({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/sales-agents',
      data: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': 'sales_agent',
        'status': 'active',
      },
      options: _adminOptions,
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty create sales agent response');
    }

    _ensureSuccess(data, fallbackMessage: 'Failed to create sales agent');
  }

  Future<void> updateSalesAgent({
    required int id,
    required String name,
    required String email,
    String? password,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      if (password != null && password.trim().isNotEmpty)
        'password': password.trim(),
    };

    final response = await _apiClient.put<Map<String, dynamic>>(
      '/admin/sales-agents/$id',
      data: payload,
      options: _adminOptions,
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty update sales agent response');
    }

    _ensureSuccess(data, fallbackMessage: 'Failed to update sales agent');
  }

  Future<void> updateSalesAgentStatus({
    required int id,
    required String status,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/admin/sales-agents/$id/status',
      data: <String, dynamic>{'status': status},
      options: _adminOptions,
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty update sales agent status response');
    }

    _ensureSuccess(
      data,
      fallbackMessage: 'Failed to update sales agent status',
    );
  }

  Future<void> deleteSalesAgent({required int id}) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/admin/sales-agents/$id',
      options: _adminOptions,
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty delete sales agent response');
    }

    _ensureSuccess(data, fallbackMessage: 'Failed to delete sales agent');
  }

  Future<List<Map<String, dynamic>>> getBusinessTypes() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/business-types',
    );
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty business types response');
    }

    _ensureSuccess(
      responseData,
      fallbackMessage: 'Failed to fetch business types',
    );

    final rawData = responseData['data'];
    if (rawData is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

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
  }) async {
    final payload = <String, dynamic>{
      'owner_name': ownerName,
      'tenant_name': tenantName,
      'tenant_slug': tenantSlug,
      'business_mode': businessMode,
      'business_type_id': businessTypeId,
      'tenant_whatsapp_number': tenantWhatsappNumber,
      'activation_channel': activationChannel,
    };

    final normalizedEmail = ownerEmail.trim();
    final normalizedPassword = password.trim();
    if (normalizedEmail.isNotEmpty) {
      payload['owner_email'] = normalizedEmail;
    }
    if (normalizedPassword.isNotEmpty) {
      payload['password'] = normalizedPassword;
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/onboarding/owner',
      data: payload,
      options: _adminOptions,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty onboard owner response');
    }

    _ensureSuccess(responseData, fallbackMessage: 'Failed to onboard owner');

    final data = responseData['data'];
    if (data is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createActivationCode({
    required String code,
    required int durationMonths,
    String? note,
    int? soldByUserId,
    int? usageLimit,
    String? expiresAt,
  }) async {
    final payload = <String, dynamic>{
      'code': code,
      'duration_months': durationMonths,
      'note': note,
      'sold_by_user_id': soldByUserId,
      'usage_limit': usageLimit,
      'expires_at': expiresAt,
    };

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/subscriptions/codes',
      data: payload,
      options: _adminOptions,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty activation code response');
    }

    _ensureSuccess(
      responseData,
      fallbackMessage: 'Failed to create activation code',
    );

    final data = responseData['data'];
    if (data is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> redeemTenantOwner({
    required String code,
    required int tenantId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/subscriptions/redeem',
      data: <String, dynamic>{'code': code, 'tenant_id': tenantId},
      options: _adminOptions,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty redeem response');
    }

    _ensureSuccess(responseData, fallbackMessage: 'Failed to redeem code');

    final data = responseData['data'];
    if (data is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getCreatedOwnersReport({
    int? salesAgentId,
    int perPage = 20,
  }) async {
    final query = <String, dynamic>{'per_page': perPage};
    if (salesAgentId != null) {
      query['sales_agent_id'] = salesAgentId;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/sales-agents/reports/created-owners',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRevenueByAgentReport({
    int? salesAgentId,
    String? createdFrom,
    String? createdTo,
  }) async {
    final query = <String, dynamic>{};
    if (salesAgentId != null) {
      query['sales_agent_id'] = salesAgentId;
    }
    if (createdFrom != null && createdFrom.trim().isNotEmpty) {
      query['created_from'] = createdFrom.trim();
    }
    if (createdTo != null && createdTo.trim().isNotEmpty) {
      query['created_to'] = createdTo.trim();
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/revenue/by-agent',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTopRevenueAgents({int limit = 10}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/revenue/top-agents',
      queryParameters: <String, dynamic>{'limit': limit},
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getActiveSubscriptionsReport({
    int? createdByAgentId,
    int perPage = 20,
  }) async {
    final query = <String, dynamic>{'per_page': perPage};
    if (createdByAgentId != null) {
      query['created_by_agent_id'] = createdByAgentId;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions-management/active',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getExpiredSubscriptionsReport({
    int? createdByAgentId,
    int perPage = 20,
  }) async {
    final query = <String, dynamic>{'per_page': perPage};
    if (createdByAgentId != null) {
      query['created_by_agent_id'] = createdByAgentId;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions-management/expired',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getExpiringSoonSubscriptionsReport({
    int? createdByAgentId,
    int days = 7,
    int perPage = 20,
  }) async {
    final query = <String, dynamic>{'days': days, 'per_page': perPage};
    if (createdByAgentId != null) {
      query['created_by_agent_id'] = createdByAgentId;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions-management/expiring-soon',
      queryParameters: query,
      options: _adminOptions,
    );

    return response.data ?? const <String, dynamic>{};
  }

  void _ensureSuccess(
    Map<String, dynamic> responseData, {
    required String fallbackMessage,
  }) {
    final success = responseData['success'];
    if (success is bool && !success) {
      final message = responseData['message'];
      if (message is String && message.isNotEmpty) {
        throw Exception(message);
      }
      throw Exception(fallbackMessage);
    }
  }
}
