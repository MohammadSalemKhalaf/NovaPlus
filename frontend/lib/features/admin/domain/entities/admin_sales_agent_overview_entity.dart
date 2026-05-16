class AdminSalesAgentOverviewEntity {
  const AdminSalesAgentOverviewEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.ownersCount,
    required this.storesCount,
  });

  final int id;
  final String name;
  final String email;
  final String status;
  final int ownersCount;
  final int storesCount;
}
