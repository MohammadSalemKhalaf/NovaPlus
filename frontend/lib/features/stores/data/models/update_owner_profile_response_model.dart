class UpdateOwnerProfileResponseModel {
  const UpdateOwnerProfileResponseModel({
    required this.success,
    required this.message,
    required this.owner,
    required this.tenant,
  });

  final bool success;
  final String message;
  final OwnerModel owner;
  final TenantModel tenant;

  factory UpdateOwnerProfileResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    final ownerRaw = dataMap['owner'];
    final ownerMap = ownerRaw is Map
        ? Map<String, dynamic>.from(ownerRaw)
        : <String, dynamic>{};

    final tenantRaw = dataMap['tenant'];
    final tenantMap = tenantRaw is Map
        ? Map<String, dynamic>.from(tenantRaw)
        : <String, dynamic>{};

    return UpdateOwnerProfileResponseModel(
      success: (json['success'] as bool?) ?? false,
      message: (json['message'] as String?) ?? '',
      owner: OwnerModel.fromJson(ownerMap),
      tenant: TenantModel.fromJson(tenantMap),
    );
  }
}

class OwnerModel {
  const OwnerModel({
    required this.id,
    required this.name,
    required this.email,
  });

  final int id;
  final String name;
  final String email;

  factory OwnerModel.fromJson(Map<String, dynamic> json) {
    return OwnerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }
}

class TenantModel {
  const TenantModel({
    required this.id,
    required this.name,
    required this.slug,
    this.whatsappNumber,
    this.storeImage,
  });

  final int id;
  final String name;
  final String slug;
  final String? whatsappNumber;
  final String? storeImage;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      storeImage: json['store_image'] as String?,
    );
  }
}
