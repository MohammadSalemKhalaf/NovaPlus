class SalesAgentStoreEntity {
  const SalesAgentStoreEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.ownerId,
    required this.status,
    this.expiresAt,
    this.createdBy,
  });

  final int id;
  final int tenantId;
  final String name;
  final String slug;
  final int ownerId;
  final String status; // active, pending, expired
  final DateTime? expiresAt;
  final int? createdBy; // Sales agent who created this store
}
