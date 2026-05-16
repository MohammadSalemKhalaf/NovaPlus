import 'dart:convert';

import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/login_credentials_entity.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';
import '../models/login_tenant_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorage secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorage _secureStorage;

  @override
  Future<AuthSessionEntity> login(LoginCredentialsEntity credentials) async {
    await _secureStorage.clearSession();

    final request = LoginRequestModel(
      email: credentials.email,
      password: credentials.password,
      deviceId: credentials.deviceId,
    );

    LoginResponseModel response;
    var roleResolutionType = credentials.loginType;

    if (credentials.loginType == LoginType.endUser) {
      response = await _remoteDataSource.loginEndUser(request);

      // If user signed in from end-user form, probe admin auth with same credentials.
      // This catches owner/admin/sales-agent accounts that otherwise appear as end_user.
      final endUserResolvedRole = await _resolveRole(
        loginType: LoginType.endUser,
        responseRole: response.role,
        responseTenants: response.tenants,
        accessToken: response.token,
      );

      if (endUserResolvedRole == 'end_user') {
        try {
          final privilegedResponse = await _remoteDataSource.loginAdmin(request);
          final privilegedRole = await _resolveRole(
            loginType: LoginType.admin,
            responseRole: privilegedResponse.role,
            responseTenants: privilegedResponse.tenants,
            accessToken: privilegedResponse.token,
          );

          final hasExplicitAdminRole =
              privilegedRole == 'admin' &&
              privilegedResponse.role.trim().toLowerCase() != 'end_user';

          if (privilegedRole == 'owner' ||
              privilegedRole == 'sales_agent' ||
              hasExplicitAdminRole) {
            response = privilegedResponse;
            roleResolutionType = LoginType.admin;
          }
        } catch (_) {
          // Keep the end-user session when admin probe is not authorized.
        }
      }
    } else {
      response = switch (credentials.loginType) {
        LoginType.endUser => await _remoteDataSource.loginEndUser(request),
        LoginType.owner => await _remoteDataSource.loginOwner(request),
        LoginType.admin => await _remoteDataSource.loginAdmin(request),
      };
    }

    final resolvedRole = await _resolveRole(
      loginType: roleResolutionType,
      responseRole: response.role,
      responseTenants: response.tenants,
      accessToken: response.token,
    );

    final tenantId = response.tenantId.trim();
    var tenants = response.tenants
        .map(
          (item) => TenantEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
            role: item.role,
          ),
        )
        .toList(growable: false);

    // Save authentication tokens and user info
    await _secureStorage.saveToken(response.token);
    await _secureStorage.saveUserRole(resolvedRole);
    await _secureStorage.saveOwnerName(response.ownerName ?? '');
    await _secureStorage.saveOwnerEmail(response.ownerEmail ?? '');
    var resolvedTenantId = '';
    if (resolvedRole != 'admin') {
      resolvedTenantId = tenantId.isNotEmpty
          ? tenantId
          : (await _remoteDataSource.ensureTenantId(preferStored: false))?.trim() ?? '';

      if (resolvedRole == 'owner') {
        if (tenants.isEmpty) {
          final fetchedTenants = await _remoteDataSource.fetchAdminMeTenants();
          tenants = fetchedTenants
              .map(
                (item) => TenantEntity(
                  id: item.id,
                  name: item.name,
                  slug: item.slug,
                  role: item.role,
                ),
              )
              .toList(growable: false);
        }

        final ownerTenant = tenants.where((tenant) => tenant.role.trim().toLowerCase() == 'owner').firstOrNull;
        if (ownerTenant != null) {
          resolvedTenantId = ownerTenant.id.toString();
        } else if (resolvedTenantId.isEmpty) {
          resolvedTenantId = tenants.firstOrNull?.id.toString() ?? '';
        }
      }

      if (resolvedRole == 'owner' && resolvedTenantId.isEmpty) {
        throw Exception('Tenant context is required');
      }

      if (resolvedTenantId.isNotEmpty) {
        await _secureStorage.saveTenantId(resolvedTenantId);
      }
    }

    await _secureStorage.saveUserTenants(
      jsonEncode(
        tenants
            .map(
              (tenant) => <String, dynamic>{
                'id': tenant.id,
                'name': tenant.name,
                'slug': tenant.slug,
                'role': tenant.role,
              },
            )
            .toList(growable: false),
      ),
    );

    return AuthSessionEntity(
      token: response.token,
      role: resolvedRole,
      tenantId: resolvedTenantId,
      tenants: tenants,
      ownerName: response.ownerName,
      ownerEmail: response.ownerEmail,
    );
  }

  Future<String> _resolveRole({
    required LoginType loginType,
    required String responseRole,
    required List<LoginTenantModel> responseTenants,
    required String accessToken,
  }) async {
    final normalizedResponseRole = responseRole.trim().toLowerCase();
    if (normalizedResponseRole == 'admin' ||
        normalizedResponseRole == 'owner' ||
        normalizedResponseRole == 'sales_agent') {
      return normalizedResponseRole;
    }

    final tenantRoles = responseTenants
        .map((tenant) => tenant.role.trim().toLowerCase())
        .toList(growable: false);

    if (tenantRoles.contains('owner')) {
      return 'owner';
    }

    final isSalesAgent = await _remoteDataSource.isSalesAgentToken(
      accessToken: accessToken,
    );
    if (isSalesAgent) {
      return 'sales_agent';
    }

    if (loginType == LoginType.owner) {
      return 'owner';
    }

    if (loginType == LoginType.endUser) {
      return 'end_user';
    }

    return 'admin';
  }

  @override
  Future<String> getProfile() async {
    final profile = await _remoteDataSource.getProfile();
    return profile.normalizedRole;
  }
}
