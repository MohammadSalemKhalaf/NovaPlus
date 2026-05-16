class ProfileResponseModel {
  const ProfileResponseModel({
    required this.roles,
    required this.email,
    required this.name,
  });

  final List<String> roles;
  final String? email;
  final String? name;

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid profile response structure');
    }

    final rolesRaw = data['roles'];
    List<String> roles = [];
    
    if (rolesRaw is List) {
      roles = rolesRaw
          .map((role) => role.toString().trim().toLowerCase())
          .toList();
    }

    if (roles.isEmpty) {
      throw Exception('No roles found in profile');
    }

    return ProfileResponseModel(
      roles: roles,
      email: data['email'] as String?,
      name: data['name'] as String?,
    );
  }

  /// Get the primary role (first in the list)
  String get primaryRole => roles.isNotEmpty ? roles.first : 'guest';

  /// Normalize role for navigation
  String get normalizedRole {
    final role = primaryRole;
    if (role == 'end_user') {
      return 'end_user';
    }
    if (role == 'store_owner') {
      return 'owner';
    }
    if (role == 'sales_agent') {
      return 'sales_agent';
    }
    if (role == 'super_admin') {
      return 'admin';
    }
    return 'guest';
  }
}
