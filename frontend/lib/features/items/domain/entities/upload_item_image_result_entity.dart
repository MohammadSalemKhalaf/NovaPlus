class UploadItemImageResultEntity {
  const UploadItemImageResultEntity({
    required this.success,
    required this.message,
    this.imageId,
    this.storagePath,
  });

  final bool success;
  final String message;
  final int? imageId;
  final String? storagePath;
}
