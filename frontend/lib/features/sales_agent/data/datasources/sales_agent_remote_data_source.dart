import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../models/sales_agent_response_parser.dart';

class SalesAgentRemoteDataSource {
  SalesAgentRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  static final Options _skipTenantOptions = Options(
    headers: <String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Skip-Tenant-ID': '1',
    },
  );

  Future<Map<String, dynamic>> getMe() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/auth/me',
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to load user profile',
    );

    return payload;
  }

  Future<void> logout() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/auth/logout',
      data: const <String, dynamic>{},
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to logout',
    );
  }

  Future<List<Map<String, dynamic>>> getBusinessTypes() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/business-types',
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to load business types',
    );

    return SalesAgentResponseParser.dataList(payload);
  }

  Future<Map<String, dynamic>> onboardOwner({
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
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/onboarding/owner',
      data: <String, dynamic>{
        'owner_name': ownerName,
        'owner_email': ownerEmail,
        'password': password,
        'tenant_name': tenantName,
        'tenant_slug': tenantSlug,
        'business_mode': businessMode,
        'activation_channel': activationChannel,
        'business_type_id': businessTypeId,
        'tenant_whatsapp_number': tenantWhatsappNumber,
      },
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to onboard owner',
    );

    return SalesAgentResponseParser.dataMap(payload);
  }

  Future<Map<String, dynamic>> createActivationCode({
    required int durationMonths,
    String? code,
    String? note,
    required int soldByUserId,
  }) async {
    final payload = <String, dynamic>{
      'duration_months': durationMonths,
      'sold_by_user_id': soldByUserId,
    };

    final normalizedCode = (code ?? '').trim();
    final normalizedNote = (note ?? '').trim();

    if (normalizedCode.isNotEmpty) {
      payload['code'] = normalizedCode;
    }
    if (normalizedNote.isNotEmpty) {
      payload['note'] = normalizedNote;
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/subscriptions/codes',
      data: payload,
      options: _skipTenantOptions,
    );

    final body = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      body,
      fallbackMessage: 'Failed to create activation code',
    );

    return SalesAgentResponseParser.dataMap(body);
  }

  Future<Map<String, dynamic>> redeemSubscription({
    required String code,
    required int tenantId,
  }) async {
    print('FINAL TENANT USED: $tenantId');
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/subscriptions/redeem',
      data: <String, dynamic>{
        'code': code,
        'tenant_id': tenantId,
      },
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to redeem subscription',
    );

    return SalesAgentResponseParser.dataMap(payload);
  }

  Future<Map<String, dynamic>> getLatestActiveCode() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/subscriptions/codes/latest-active',
      options: _skipTenantOptions,
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to load latest activation code',
    );

    return SalesAgentResponseParser.dataMap(payload);
  }

  Future<void> updateProfile({
    String? email,
    String? password,
  }) async {
    final body = <String, dynamic>{};

    final normalizedEmail = email?.trim() ?? '';
    final normalizedPassword = password?.trim() ?? '';

    if (normalizedEmail.isNotEmpty) {
      body['email'] = normalizedEmail;
    }

    if (normalizedPassword.isNotEmpty) {
      body['password'] = normalizedPassword;
    }

    if (body.isEmpty) {
      throw Exception('No changes to update');
    }

    final response = await _apiClient.put<Map<String, dynamic>>(
      '/sales-agent/profile',
      data: body,
    );

    final payload = response.data;
    if (payload == null) {
      return;
    }

    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to update profile',
    );
  }

  Future<List<Map<String, dynamic>>> getOwners() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/sales-agent/owners',
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to load owners',
    );

    return SalesAgentResponseParser.dataListByKey(payload, 'owners');
  }

  Future<List<Map<String, dynamic>>> getStores() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/sales-agent/stores',
    );

    final payload = response.data ?? const <String, dynamic>{};
    SalesAgentResponseParser.ensureSuccess(
      payload,
      fallbackMessage: 'Failed to load stores',
    );

    return SalesAgentResponseParser.dataListByKey(payload, 'stores');
  }
}
