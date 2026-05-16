class UploadItemImageInputEntity {
  const UploadItemImageInputEntity({
    required this.itemId,
    required this.imagePath,
    this.altText,
    this.sortOrder,
    this.isPrimary,
  });

  final int itemId;
  final String imagePath;
  final String? altText;
  final int? sortOrder;
  final bool? isPrimary;
}
