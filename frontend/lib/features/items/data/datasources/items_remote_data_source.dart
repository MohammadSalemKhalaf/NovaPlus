import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../models/create_item_request_model.dart';
import '../models/create_item_response_model.dart';
import '../models/items_response_model.dart';
import '../models/set_active_price_request_model.dart';
import '../models/set_active_price_response_model.dart';
import '../models/upload_item_image_request_model.dart';
import '../models/upload_item_image_response_model.dart';

class ItemsRemoteDataSource {
  ItemsRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ItemsResponseModel> getItems({
    String? search,
    int? categoryId,
  }) async {
    final query = <String, dynamic>{};

    final normalizedSearch = (search ?? '').trim();
    if (normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    }

    if (categoryId != null && categoryId > 0) {
      query['category_id'] = categoryId;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/owner/catalog/items',
      queryParameters: query.isEmpty ? null : query,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty items response');
    }

    debugPrint('Final item response: ${jsonEncode(responseData)}');

    try {
      return ItemsResponseModel.fromJson(responseData);
    } catch (error, stackTrace) {
      debugPrint('CATALOG PARSE ERROR: $error');
      debugPrint('CATALOG PARSE STACK: $stackTrace');
      rethrow;
    }
  }

  Future<CreateItemResponseModel> createItem(CreateItemRequestModel request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/owner/catalog/items',
      data: request.toJson(),
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty create item response');
    }

    return CreateItemResponseModel.fromJson(responseData);
  }

  Future<UploadItemImageResponseModel> uploadItemImage(UploadItemImageRequestModel request) async {
    final fileName = request.imagePath.split(RegExp(r'[\\/]')).last;

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(request.imagePath, filename: fileName),
    });

    debugPrint('Upload image request payload type: ${formData.runtimeType}');

    Response<Map<String, dynamic>> response;
    try {
      response = await _apiClient.post<Map<String, dynamic>>(
        '/admin/catalog/items/${request.itemId}/images',
        data: formData,
      );
    } on DioException catch (error) {
      debugPrint('Upload image error response body: ${error.response?.data}');
      rethrow;
    }

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty upload image response');
    }

    debugPrint('Upload response full JSON: ${jsonEncode(responseData)}');

    final parsed = UploadItemImageResponseModel.fromJson(responseData);
    debugPrint('Extracted image_id: ${parsed.imageId}');

    return parsed;
  }

  Future<SetActivePriceResponseModel> setActivePrice({
    required int itemId,
    required SetActivePriceRequestModel request,
  }) async {
    debugPrint('ITEM ID: $itemId');
    debugPrint('SETTING PRICE...');

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/catalog/items/$itemId/prices/active',
      data: request.toJson(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set item price');
    }

    final responseData = response.data;
    if (responseData == null) {
      return const SetActivePriceResponseModel(
        success: true,
        message: 'Price set successfully',
      );
    }

    return SetActivePriceResponseModel.fromJson(responseData);
  }

  Future<void> updateItem({
    required int id,
    required Map<String, dynamic> data,
  }) async {
    Response<Map<String, dynamic>> response;
    try {
      response = await _apiClient.patch<Map<String, dynamic>>(
        '/owner/catalog/items/$id',
        data: data,
      );
    } on DioException catch (error) {
      // Keep compatibility if server exposes only PUT for this endpoint.
      if (error.response?.statusCode != 405) {
        rethrow;
      }

      response = await _apiClient.put<Map<String, dynamic>>(
        '/owner/catalog/items/$id',
        data: data,
      );
    }

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty update item response');
    }

    if (responseData['success'] != true) {
      final message = responseData['message'] as String?;
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Failed to update item',
      );
    }
  }

  Future<void> deleteItem(int id) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/owner/catalog/items/$id',
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty delete item response');
    }

    if (responseData['success'] != true) {
      final message = responseData['message'] as String?;
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Failed to delete item',
      );
    }
  }
}
