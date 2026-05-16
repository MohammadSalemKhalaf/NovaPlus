class CreateItemRequestModel {
  const CreateItemRequestModel({
    required this.name,
    required this.slug,
    required this.itemType,
    required this.status,
    required this.visibility,
    required this.sortOrder,
    this.categoryId,
    this.shortDescription,
    this.longDescription,
    this.primaryImageId,
  });

  final String name;
  final String slug;
  final String itemType;
  final String status;
  final String visibility;
  final int sortOrder;
  final int? categoryId;
  final String? shortDescription;
  final String? longDescription;
  final int? primaryImageId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'short_description': shortDescription,
      'long_description': longDescription,
      'item_type': itemType,
      'status': status,
      'visibility': visibility,
      'primary_image_id': primaryImageId,
      'sort_order': sortOrder,
    };
  }
}
