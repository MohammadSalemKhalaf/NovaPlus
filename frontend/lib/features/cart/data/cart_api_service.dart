import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage.dart';

class CartApiService {
  CartApiService({Dio? dio, String? baseUrl, SecureStorage? secureStorage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.baseUrl,
              headers: const <String, dynamic>{'Accept': 'application/json'},
            ),
          ),
      _secureStorage = secureStorage ?? SecureStorage();

  final Dio _dio;
  final SecureStorage _secureStorage;

  Future<Map<String, dynamic>> getCart({
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.get<Map<String, dynamic>>(
      '/public/cart',
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty cart response');
  }

  Future<Map<String, dynamic>> getEndUserCart() async {
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'X-Skip-Tenant-ID': '1',
    });
    final response = await _dio.get<Map<String, dynamic>>(
      '/enduser/cart',
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty end-user cart response');
  }

  Future<Map<String, dynamic>> addItem({
    required int itemId,
    required int quantity,
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/public/cart/items',
      data: <String, dynamic>{'item_id': itemId, 'quantity': quantity},
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty add item response');
  }

  Future<Map<String, dynamic>> removeItem({
    required int itemId,
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.delete<Map<String, dynamic>>(
      '/public/cart/items/$itemId',
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty remove item response');
  }

  Future<Map<String, dynamic>> incrementItem({
    required int itemId,
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/public/cart/items/increment',
      data: <String, dynamic>{'item_id': itemId},
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty increment item response');
  }

  Future<Map<String, dynamic>> decrementItem({
    required int itemId,
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/public/cart/items/decrement',
      data: <String, dynamic>{'item_id': itemId},
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty decrement item response');
  }

  Future<Map<String, dynamic>> clearCart({
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/public/cart/clear',
      data: const <String, dynamic>{},
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty clear cart response');
  }

  Future<Map<String, dynamic>> checkoutWhatsApp({
    required String deviceId,
    required int tenantId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final headers = await _withAuthHeaders(<String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Tenant-ID': resolvedTenantId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/public/cart/checkout-whatsapp',
      data: const <String, dynamic>{},
      options: Options(headers: headers),
    );

    return _ensureMap(response.data, 'Empty checkout response');
  }

  Future<Map<String, dynamic>> getPublicItemDetail({
    required int tenantId,
    required int itemId,
  }) async {
    final resolvedTenantId = await _resolveTenantId(tenantId);
    final response = await _dio.get<Map<String, dynamic>>(
      '/public/tenants/$resolvedTenantId/items/$itemId',
      options: Options(
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );

    return _ensureMap(response.data, 'Empty item detail response');
  }

  Map<String, dynamic> _ensureMap(Map<String, dynamic>? data, String message) {
    if (data == null) {
      throw Exception(message);
    }
    return data;
  }

  Future<String> _resolveTenantId(int tenantId) async {
    if (tenantId > 0) {
      final resolved = tenantId.toString();
      await _secureStorage.saveTenantId(resolved);
      return resolved;
    }

    final storedTenantId = (await _secureStorage.getTenantId())?.trim();
    if (storedTenantId != null && storedTenantId.isNotEmpty) {
      return storedTenantId;
    }

    throw Exception('Tenant context is required');
  }

  Future<Map<String, dynamic>> _withAuthHeaders(
    Map<String, dynamic> headers,
  ) async {
    final token = await _secureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
