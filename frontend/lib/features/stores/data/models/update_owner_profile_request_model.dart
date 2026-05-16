import 'package:dio/dio.dart';

class UpdateOwnerProfileRequestModel {
  const UpdateOwnerProfileRequestModel({
    this.name,
    this.tenantWhatsappNumber,
    this.tenantStoreImage,
    this.tenantStoreImageFilePath,
    this.password,
  });

  final String? name;
  final String? tenantWhatsappNumber;
  final String? tenantStoreImage;
  final String? tenantStoreImageFilePath;
  final String? password;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    // Only include non-empty fields
    if (name != null && name!.isNotEmpty) {
      json['name'] = name;
    }

    if (tenantWhatsappNumber != null && tenantWhatsappNumber!.isNotEmpty) {
      json['tenant_whatsapp_number'] = tenantWhatsappNumber;
    }

    if (tenantStoreImage != null) {
      json['tenant_store_image'] = tenantStoreImage;
    }

    // Only include password if it's not empty
    if (password != null && password!.isNotEmpty) {
      json['password'] = password;
    }

    return json;
  }

  Future<Object> toRequestPayload() async {
    final json = toJson();
    final filePath = tenantStoreImageFilePath?.trim();

    if (filePath == null || filePath.isEmpty) {
      return json;
    }

    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    return FormData.fromMap({
      ...json,
      'tenant_store_image_file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
  }
}
