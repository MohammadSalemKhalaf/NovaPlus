import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../models/admin_login_request_model.dart';
import '../models/admin_login_response_model.dart';

class AdminAuthRemoteDataSource {
  AdminAuthRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AdminLoginResponseModel> login(AdminLoginRequestModel request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/auth/login',
      data: request.toJson(),
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty admin login response');
    }

    debugPrint('Admin login backend response: ${jsonEncode(responseData)}');

    final successField = responseData['success'];
    if (successField is bool && !successField) {
      final message = responseData['message'] as String?;
      throw Exception(message ?? 'Admin login failed');
    }

    return AdminLoginResponseModel.fromJson(responseData);
  }
}
