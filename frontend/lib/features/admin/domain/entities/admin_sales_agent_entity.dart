class AdminSalesAgentEntity {
  const AdminSalesAgentEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.roles,
  });

  final int id;
  final String name;
  final String email;
  final String status;
  final List<String> roles;
}
