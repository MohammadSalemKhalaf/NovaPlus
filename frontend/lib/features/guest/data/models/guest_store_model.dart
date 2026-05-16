import 'business_type_model.dart';

class GuestStoreModel {
  const GuestStoreModel({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    this.businessType,
  });

  final int id;
  final String name;
  final String slug;
  final String? image;
  final BusinessTypeModel? businessType;

  factory GuestStoreModel.fromJson(Map<String, dynamic> json) {
    final businessType = json['business_type'];
    final businessTypeModel = businessType is Map
        ? BusinessTypeModel.fromJson(Map<String, dynamic>.from(businessType))
        : null;

    final image = _readImage(json);

    return GuestStoreModel(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      image: image,
      businessType: businessTypeModel,
    );
  }

  static String? _readImage(Map<String, dynamic> json) {
    final direct = json['image']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final storeImage = json['store_image']?.toString().trim();
    if (storeImage != null && storeImage.isNotEmpty) {
      return storeImage;
    }

    final primaryImage = json['primary_image'];
    if (primaryImage is Map) {
      final mapped = Map<String, dynamic>.from(primaryImage);
      final storagePath = mapped['storage_path']?.toString().trim();
      if (storagePath != null && storagePath.isNotEmpty) {
        return storagePath;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    if (image != null) 'image': image,
    if (businessType != null) 'business_type': businessType!.toJson(),
  };
}
