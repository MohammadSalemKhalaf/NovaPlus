class StoreEntity {
  const StoreEntity({
    required this.id,
    this.tenantId,
    required this.name,
    required this.slug,
    this.businessTypeId,
    this.businessTypeName,
    this.businessTypeSlug,
  });

  final int id;
  final int? tenantId;
  final String name;
  final String slug;
  final int? businessTypeId;
  final String? businessTypeName;
  final String? businessTypeSlug;

  int get resolvedStoreId => tenantId ?? id;

  @override
  String toString() {
    return 'StoreEntity(id: $id, tenantId: $tenantId, resolvedStoreId: $resolvedStoreId, name: $name, slug: $slug)';
  }
}
