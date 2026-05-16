class OfferEntity {
  const OfferEntity({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.status,
    required this.createdBy,
    required this.itemIds,
    this.description,
    this.image,
    this.discountType,
    this.discountValue,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int tenantId;
  final String title;
  final String? description;
  final String? image;
  final String? discountType;
  final num? discountValue;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final int createdBy;
  final List<int> itemIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasDiscount =>
      (discountType ?? '').trim().isNotEmpty && discountValue != null;

  bool get isActive => status.trim().toLowerCase() == 'active';
}