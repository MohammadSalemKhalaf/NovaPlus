import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient({
    required SecureStorage secureStorage,
    Dio? dio,
    String? baseUrl,
  }) : _secureStorage = secureStorage,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? AppConfig.baseUrl,
               headers: const <String, dynamic>{'Accept': 'application/json'},
             ),
           );

  final SecureStorage _secureStorage;
  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final requestOptions = await _withInjectedHeaders(path, options);

    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: requestOptions,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final requestOptions = await _withInjectedHeaders(path, options);

    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: requestOptions,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final requestOptions = await _withInjectedHeaders(path, options);

    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: requestOptions,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final requestOptions = await _withInjectedHeaders(path, options);

    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: requestOptions,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final requestOptions = await _withInjectedHeaders(path, options);

    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: requestOptions,
    );
  }

  Future<void> resetSessionHeaders() async {
    _dio.options.headers.remove('Authorization');
    _dio.options.headers.remove('X-Tenant-ID');
  }

  Future<Options> _withInjectedHeaders(String path, Options? options) async {
    final token = await _secureStorage.getToken();
    final role = (await _secureStorage.getUserRole())?.trim().toLowerCase();
    final tenantId = await ensureTenantId();

    final headers = Map<String, dynamic>.from(
      options?.headers ?? const <String, dynamic>{},
    );
    final skipTenantHeader = headers.remove('X-Skip-Tenant-ID') != null ||
        path.startsWith('/admin');

    final isGuest = role == 'guest';
    if (!isGuest && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (!skipTenantHeader && tenantId != null && tenantId.isNotEmpty) {
      headers['X-Tenant-ID'] = tenantId;
    }

    return (options ?? Options()).copyWith(headers: headers);
  }

  Future<String?> ensureTenantId({bool preferStored = true}) async {
    return _resolveTenantId(preferStored: preferStored);
  }

  Future<String?> _resolveTenantId({required bool preferStored}) async {
    final rawTenantId = (await _secureStorage.getTenantId())?.trim();
    if (rawTenantId == null || rawTenantId.isEmpty) {
      return null;
    }

    return rawTenantId;
  }
}
