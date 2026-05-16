class TenantEntity {
  const TenantEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.role,
  });

  final int id;
  final String name;
  final String slug;
  final String role;
}
