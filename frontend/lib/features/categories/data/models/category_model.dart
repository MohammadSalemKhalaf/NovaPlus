class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.parentId,
    required this.status,
    this.description,
  });

  final int id;
  final String name;
  final String slug;
  final int? parentId;
  final String status;
  final String? description;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      parentId: json['parent_id'] as int?,
      status: json['status'] as String,
      description: json['description'] as String?,
    );
  }
}
