import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/categories_response_model.dart';

class CategoriesRemoteDataSource {
  CategoriesRemoteDataSource({
    required ApiClient apiClient,
    SecureStorage? secureStorage,
  }) : _apiClient = apiClient,
       _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  Future<CategoriesResponseModel> getCategories() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/owner/catalog/categories');
    final responseData = response.data;

    if (responseData == null) {
      throw Exception('Empty categories response');
    }

    return CategoriesResponseModel.fromJson(responseData);
  }

  Future<CategoriesResponseModel> getCategoriesByStore(int storeId) async {
    await _secureStorage.saveTenantId(storeId.toString());
    return getCategories();
  }

  /// Get public categories for a store (no authentication needed)
  /// Uses the public endpoint: GET /public/stores/{storeId}
  /// Extracts categories from response.data.categories
  Future<CategoriesResponseModel> getPublicCategoriesByStore(int storeId) async {
    try {
      debugPrint('[Categories] Calling store endpoint with tenantId: $storeId');
      debugPrint('Calling: /public/stores/$storeId');
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/public/stores/$storeId',
      );
      final responseData = response.data;
      debugPrint('FULL RESPONSE: $responseData');

      if (responseData == null) {
        debugPrint('[Categories] Empty public store response from backend');
        // Return empty categories response
        return CategoriesResponseModel.fromJson({
          'data': [],
          'success': true,
          'message': 'No categories available',
          'meta': {},
        });
      }

      // Extract categories from either:
      // 1) response.data['categories']
      // 2) response.data['data']['categories']
      final nestedData = responseData['data'];
      final rawCategories =
          responseData['categories'] ??
          (nestedData is Map ? Map<String, dynamic>.from(nestedData)['categories'] : null) ??
          const <dynamic>[];

      final categories = rawCategories is List ? rawCategories : const <dynamic>[];
      if (categories.isEmpty) {
        debugPrint('[Categories] No categories found in store response for store $storeId');
      }

      debugPrint('[Categories] Public categories loaded successfully for store $storeId');
      // Construct response with extracted categories
      return CategoriesResponseModel.fromJson({
        'data': categories,
        'success': true,
        'message': 'Categories loaded successfully',
        'meta': {},
      });
    } on DioException catch (e) {
      debugPrint('[Categories] Error loading public categories for store $storeId');
      debugPrint('[Categories] Status: ${e.response?.statusCode}');
      debugPrint('[Categories] Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      // Non-request parsing edge cases should not break guest browsing.
      debugPrint('[Categories] Unexpected parse issue, returning empty categories: $e');
      return CategoriesResponseModel.fromJson({
        'data': [],
        'success': true,
        'message': 'No categories available',
        'meta': {},
      });
    }
  }

  Future<void> createCategory({
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/owner/catalog/categories',
      data: <String, dynamic>{
        'name': name,
        'slug': slug,
        'status': status,
        'sort_order': sortOrder,
      },
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty create category response');
    }

    if (responseData['success'] != true) {
      final message = responseData['message'] as String?;
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Failed to create category',
      );
    }
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/owner/catalog/categories/$id',
      data: <String, dynamic>{
        'name': name,
        'slug': slug,
        'status': status,
        'sort_order': sortOrder,
      },
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty update category response');
    }

    if (responseData['success'] != true) {
      final message = responseData['message'] as String?;
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Failed to update category',
      );
    }
  }

  Future<void> deleteCategory(int id) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/owner/catalog/categories/$id',
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty delete category response');
    }

    if (responseData['success'] != true) {
      final message = responseData['message'] as String?;
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Failed to delete category',
      );
    }
  }
}
