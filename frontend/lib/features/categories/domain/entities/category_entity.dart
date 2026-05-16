class CategoryEntity {
  const CategoryEntity({
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
}
