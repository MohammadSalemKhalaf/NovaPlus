class LoginTenantModel {
  const LoginTenantModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.role,
  });

  final int id;
  final String name;
  final String slug;
  final String role;

  factory LoginTenantModel.fromJson(Map<String, dynamic> json) {
    return LoginTenantModel(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      role: json['role'] as String,
    );
  }
}
