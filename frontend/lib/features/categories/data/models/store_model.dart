class StoreModel {
  const StoreModel({
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

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final businessType = json['business_type'];
    final businessTypeMap = businessType is Map
        ? Map<String, dynamic>.from(businessType)
        : null;

    return StoreModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tenantId: (json['tenant_id'] as num?)?.toInt(),
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      businessTypeId: (businessTypeMap?['id'] as num?)?.toInt(),
      businessTypeName: businessTypeMap?['name'] as String?,
      businessTypeSlug: businessTypeMap?['slug'] as String?,
    );
  }
}
