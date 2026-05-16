import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';
import '../models/login_tenant_model.dart';
import '../models/profile_response_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static final Options _adminOptions = Options(
    headers: <String, dynamic>{'X-Skip-Tenant-ID': 'true'},
  );

  Future<String?> ensureTenantId({bool preferStored = true}) {
    return _apiClient.ensureTenantId(preferStored: preferStored);
  }

  Future<LoginResponseModel> loginEndUser(LoginRequestModel request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/enduser/auth/login',
      data: request.toJson(),
    );

    return _parseLoginResponse(response.data);
  }

  Future<bool> isSalesAgentToken({required String accessToken}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/sales-agent/owners',
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $accessToken',
            'X-Skip-Tenant-ID': '1',
          },
        ),
      );

      final statusCode = response.statusCode ?? 0;
      return statusCode >= 200 && statusCode < 300;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 401 || statusCode == 403) {
        return false;
      }

      rethrow;
    }
  }

  Future<LoginResponseModel> loginOwner(LoginRequestModel request) async {
    return loginAdmin(request);
  }

  Future<LoginResponseModel> loginAdmin(LoginRequestModel request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/auth/login',
      data: request.toJson(),
      options: _adminOptions,
    );

    return _parseLoginResponse(response.data);
  }

  Future<List<LoginTenantModel>> fetchAdminMeTenants() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/admin/auth/me',
      options: _adminOptions,
    );
    final responseData = response.data;

    if (responseData == null) {
      return const <LoginTenantModel>[];
    }

    final data = responseData['data'];
    if (data is! Map) {
      return const <LoginTenantModel>[];
    }

    final tenantsRaw = data['tenants'];
    if (tenantsRaw is! List) {
      return const <LoginTenantModel>[];
    }

    return tenantsRaw
        .whereType<Map>()
        .map((item) => LoginTenantModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  LoginResponseModel _parseLoginResponse(Map<String, dynamic>? responseData) {
    if (responseData == null) {
      throw Exception('Empty login response');
    }

    final successField = responseData['success'];
    if (successField is bool && !successField) {
      final message = responseData['message'] as String?;
      throw Exception(message ?? 'Login failed');
    }

    return LoginResponseModel.fromJson(responseData);
  }

  /// Get authenticated user's profile
  /// 
  /// The endpoint used depends on the current auth context (token included in header).
  /// Supports: GET /enduser/auth/profile, /admin/auth/profile, /owner/profile, etc.
  Future<ProfileResponseModel> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/enduser/auth/profile',
    );

    if (response.data == null) {
      throw Exception('Empty profile response');
    }

    return ProfileResponseModel.fromJson(response.data!);
  }
}
