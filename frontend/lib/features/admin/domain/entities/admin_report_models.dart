import 'admin_business_type_entity.dart';

class BusinessTypeModel {
  const BusinessTypeModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  factory BusinessTypeModel.fromEntity(AdminBusinessTypeEntity entity) {
    return BusinessTypeModel(id: entity.id, name: entity.name, slug: entity.slug);
  }

  factory BusinessTypeModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return BusinessTypeModel(
      id: id,
      name: json['name']?.toString().trim() ?? '',
      slug: json['slug']?.toString().trim() ?? '',
    );
  }
}

class StoreModel {
  const StoreModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.businessTypeId,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String slug;
  final String status;
  final int businessTypeId;
  final String createdAt;

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    final rawBusinessTypeId = json['business_type_id'];
    var businessTypeId = rawBusinessTypeId is num
        ? rawBusinessTypeId.toInt()
        : int.tryParse(rawBusinessTypeId?.toString() ?? '') ?? 0;
    if (businessTypeId == 0 && json['business_type'] is Map) {
      final businessTypeMap = Map<String, dynamic>.from(json['business_type'] as Map);
      final nestedId = businessTypeMap['id'];
      businessTypeId = nestedId is num ? nestedId.toInt() : int.tryParse(nestedId?.toString() ?? '') ?? 0;
    }

    return StoreModel(
      id: id,
      name: json['name']?.toString().trim() ?? '',
      slug: json['slug']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      businessTypeId: businessTypeId,
      createdAt: json['created_at']?.toString().trim() ?? '',
    );
  }
}

class OwnerModel {
  const OwnerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.stores,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String createdAt;
  final List<StoreModel> stores;

  factory OwnerModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    final storesRaw = json['stores'];
    final stores = storesRaw is List
        ? storesRaw
            .whereType<Map>()
            .map((item) => StoreModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <StoreModel>[];

    return OwnerModel(
      id: id,
      name: json['name']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      role: json['role']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      createdAt: json['created_at']?.toString().trim() ?? '',
      stores: stores,
    );
  }
}

class SalesAgentModel {
  const SalesAgentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.ownersCount,
    required this.storesCount,
    required this.owners,
  });

  final int id;
  final String name;
  final String email;
  final String status;
  final String createdAt;
  final int ownersCount;
  final int storesCount;
  final List<OwnerModel> owners;

  factory SalesAgentModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    final ownersRaw = json['owners'];
    final owners = ownersRaw is List
        ? ownersRaw
            .whereType<Map>()
            .map((item) => OwnerModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <OwnerModel>[];

    final ownersCountRaw = json['owners_count'];
    final storesCountRaw = json['stores_count'];

    return SalesAgentModel(
      id: id,
      name: json['name']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      createdAt: json['created_at']?.toString().trim() ?? '',
      ownersCount: ownersCountRaw is num
          ? ownersCountRaw.toInt()
          : int.tryParse(ownersCountRaw?.toString() ?? '') ?? owners.length,
      storesCount: storesCountRaw is num
          ? storesCountRaw.toInt()
          : int.tryParse(storesCountRaw?.toString() ?? '') ??
              owners.fold<int>(0, (sum, owner) => sum + owner.stores.length),
      owners: owners,
    );
  }
}
