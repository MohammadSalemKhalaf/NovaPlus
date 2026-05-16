class UploadItemImageResponseModel {
  const UploadItemImageResponseModel({
    required this.success,
    required this.message,
    this.imageId,
    this.storagePath,
  });

  final bool success;
  final String message;
  final int? imageId;
  final String? storagePath;

  factory UploadItemImageResponseModel.fromJson(Map<String, dynamic> json) {
    final imageObject = _extractImageObject(json);
    final imageId = _extractImageId(imageObject);
    final storagePath = _extractStoragePath(imageObject);

    return UploadItemImageResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      imageId: imageId,
      storagePath: storagePath,
    );
  }

  static Map<String, dynamic>? _extractImageObject(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      final image = data['image'];
      if (image is Map) {
        return Map<String, dynamic>.from(image);
      }
    }

    final image = json['image'];
    if (image is Map) {
      return Map<String, dynamic>.from(image);
    }

    return null;
  }

  static int? _extractImageId(Map<String, dynamic>? imageObject) {
    if (imageObject == null) {
      return null;
    }

    final idRaw = imageObject['id'];
    if (idRaw is num) {
      return idRaw.toInt();
    }

    if (idRaw is String) {
      return int.tryParse(idRaw);
    }

    return null;
  }

  static String? _extractStoragePath(Map<String, dynamic>? imageObject) {
    if (imageObject == null) {
      return null;
    }

    final storagePath = imageObject['storage_path'];
    if (storagePath is String && storagePath.isNotEmpty) {
      return storagePath;
    }

    final url = imageObject['url'];
    if (url is String && url.isNotEmpty) {
      return url;
    }

    return null;
  }
}
