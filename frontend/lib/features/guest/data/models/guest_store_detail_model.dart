import 'business_type_model.dart';
import 'catalog_summary_model.dart';

class CatalogEndpointsModel {
  const CatalogEndpointsModel({
    required this.items,
    required this.categories,
  });

  final String items;
  final String categories;

  factory CatalogEndpointsModel.fromJson(Map<String, dynamic> json) {
    return CatalogEndpointsModel(
      items: json['items'] as String,
      categories: json['categories'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items,
    'categories': categories,
  };
}

class GuestStoreDetailModel {
  const GuestStoreDetailModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.businessMode,
    this.image,
    this.businessType,
    required this.catalogSummary,
    required this.catalogEndpoints,
  });

  final int id;
  final String name;
  final String slug;
  final String businessMode;
  final String? image;
  final BusinessTypeModel? businessType;
  final CatalogSummaryModel catalogSummary;
  final CatalogEndpointsModel catalogEndpoints;

  factory GuestStoreDetailModel.fromJson(Map<String, dynamic> json) {
    final businessType = json['business_type'];
    final businessTypeModel = businessType is Map
        ? BusinessTypeModel.fromJson(Map<String, dynamic>.from(businessType))
        : null;

    final catalogSummary = json['catalog_summary'];
    final catalogSummaryModel = catalogSummary is Map
        ? CatalogSummaryModel.fromJson(Map<String, dynamic>.from(catalogSummary))
        : CatalogSummaryModel(categoriesCount: 0, publicItemsCount: 0);

    final catalogEndpoints = json['catalog_endpoints'];
    final catalogEndpointsModel = catalogEndpoints is Map
        ? CatalogEndpointsModel.fromJson(Map<String, dynamic>.from(catalogEndpoints))
        : CatalogEndpointsModel(items: '', categories: '');

    final image = _readImage(json);

    return GuestStoreDetailModel(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      businessMode: json['business_mode'] as String,
      image: image,
      businessType: businessTypeModel,
      catalogSummary: catalogSummaryModel,
      catalogEndpoints: catalogEndpointsModel,
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
    'business_mode': businessMode,
    if (image != null) 'image': image,
    if (businessType != null) 'business_type': businessType!.toJson(),
    'catalog_summary': catalogSummary.toJson(),
    'catalog_endpoints': catalogEndpoints.toJson(),
  };
}
