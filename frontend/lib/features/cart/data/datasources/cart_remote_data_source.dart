import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../models/guest_add_to_cart_models.dart';

class CartRemoteDataSource {
  CartRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getPublicCart({
    required String deviceId,
    int? tenantId,
  }) async {
    final options = Options(
      headers: {
        'X-Device-ID': deviceId,
        if (tenantId != null) 'X-Tenant-ID': tenantId.toString(),
      },
    );

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/public/cart',
      options: options,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty cart response');
    }

    return responseData;
  }

  Future<Map<String, dynamic>> getEndUserCart() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/enduser/cart');

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty end-user cart response');
    }

    return responseData;
  }

  /// Preview guest cart before merging.
  /// 
  /// Endpoint: POST /enduser/guest-cart/preview
  /// Auth: Bearer token (requires user to be logged in)
  /// Body: { device_id }
  Future<Map<String, dynamic>> previewGuestCart(String deviceId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/enduser/guest-cart/preview',
        data: {
          'device_id': deviceId,
        },
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Empty preview response');
      }

      debugPrint('Cart preview response: ${jsonEncode(responseData)}');

      final successField = responseData['success'];
      if (successField is bool && !successField) {
        final message = responseData['message'] as String?;
        throw Exception(message ?? 'Failed to preview guest cart');
      }

      return responseData;
    } catch (e) {
      debugPrint('Cart preview error: $e');
      rethrow;
    }
  }

  /// Merge guest cart with authenticated user's cart.
  /// 
  /// Endpoint: POST /enduser/guest-cart/merge
  /// Auth: Bearer token (requires user to be logged in)
  /// Body: { device_id }
  /// 
  /// Response includes merged cart data with all items.
  Future<Map<String, dynamic>> mergeGuestCart(String deviceId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/enduser/guest-cart/merge',
        data: {
          'device_id': deviceId,
        },
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Empty merge response');
      }

      debugPrint('Cart merge response: ${jsonEncode(responseData)}');

      final successField = responseData['success'];
      if (successField is bool && !successField) {
        final message = responseData['message'] as String?;
        throw Exception(message ?? 'Failed to merge guest cart');
      }

      return responseData;
    } catch (e) {
      debugPrint('Cart merge error: $e');
      rethrow;
    }
  }

  /// Add item to guest cart.
  /// 
  /// Endpoint: POST /public/cart/items
  /// Header: X-Device-ID (identifies the guest cart)
  /// Body: { item_id, quantity }
  /// 
  /// Response includes item confirmation or error (e.g., different store).
  Future<AddToGuestCartResponseModel> addToGuestCart({
    required String itemId,
    required int quantity,
    required String deviceId,
    int? tenantId,
  }) async {
    try {
      final request = AddToGuestCartRequestModel(
        itemId: itemId,
        quantity: quantity,
      );

      // Create options with X-Device-ID header
      final options = Options(
        headers: {
          'X-Device-ID': deviceId,
          if (tenantId != null) 'X-Tenant-ID': tenantId.toString(),
        },
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/public/cart/items',
        data: request.toJson(),
        options: options,
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Empty add to cart response');
      }

      debugPrint('Add to cart response: ${jsonEncode(responseData)}');

      return AddToGuestCartResponseModel.fromJson(responseData);
    } catch (e) {
      debugPrint('Add to cart error: $e');
      rethrow;
    }
  }

  /// Clear guest cart.
  /// 
  /// Endpoint: DELETE /public/cart
  /// Header: X-Device-ID (identifies the guest cart)
  /// 
  /// Used when user has items from different store and wants to replace.
  Future<void> clearGuestCart({
    required String deviceId,
    int? tenantId,
  }) async {
    try {
      final options = Options(
        headers: {
          'X-Device-ID': deviceId,
          if (tenantId != null) 'X-Tenant-ID': tenantId.toString(),
        },
      );

      final response = await _apiClient.delete<Map<String, dynamic>>(
        '/public/cart',
        options: options,
      );

      final responseData = response.data;
      if (responseData != null) {
        debugPrint('Clear cart response: ${jsonEncode(responseData)}');
      }
    } catch (e) {
      debugPrint('Clear cart error: $e');
      rethrow;
    }
  }
}
