import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../models/update_owner_profile_request_model.dart';
import '../models/update_owner_profile_response_model.dart';

class OwnerProfileRemoteDataSource {
  OwnerProfileRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UpdateOwnerProfileResponseModel> updateProfile(
    UpdateOwnerProfileRequestModel request,
  ) async {
    final payload = await request.toRequestPayload();
    final response = payload is FormData
        ? await _apiClient.post<Map<String, dynamic>>(
            '/owner/profile',
            data: payload..fields.add(const MapEntry('_method', 'PUT')),
          )
        : await _apiClient.put<Map<String, dynamic>>(
            '/owner/profile',
            data: payload,
          );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty update profile response');
    }

    debugPrint(
      'Update profile backend response: ${jsonEncode(responseData)}',
    );

    final successField = responseData['success'];
    if (successField is bool && !successField) {
      final message = responseData['message'] as String?;
      throw Exception(message ?? 'Update failed');
    }

    return UpdateOwnerProfileResponseModel.fromJson(responseData);
  }
}
