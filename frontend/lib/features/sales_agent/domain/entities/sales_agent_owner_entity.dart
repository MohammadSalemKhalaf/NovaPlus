class SalesAgentOwnerEntity {
  const SalesAgentOwnerEntity({
    required this.id,
    required this.name,
    required this.email,
    this.createdBy,
  });

  final int id;
  final String name;
  final String email;
  final int? createdBy; // Sales agent who created this owner
}
