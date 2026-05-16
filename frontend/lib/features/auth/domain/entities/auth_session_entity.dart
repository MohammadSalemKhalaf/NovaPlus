import 'tenant_entity.dart';

class AuthSessionEntity {
  const AuthSessionEntity({
    required this.token,
    required this.role,
    required this.tenantId,
    required this.tenants,
    this.ownerName,
    this.ownerEmail,
  });

  final String token;
  final String role;
  final String tenantId;
  final List<TenantEntity> tenants;
  final String? ownerName;
  final String? ownerEmail;
}
