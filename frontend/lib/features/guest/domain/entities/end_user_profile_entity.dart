class EndUserProfileEntity {
  const EndUserProfileEntity({
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

  String get primaryRole {
    if (roles.isEmpty) {
      return 'end_user';
    }
    return roles.first;
  }
}
