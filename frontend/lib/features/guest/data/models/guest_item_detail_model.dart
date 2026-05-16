import 'price_model.dart';

class CategoryRefModel {
  const CategoryRefModel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory CategoryRefModel.fromJson(Map<String, dynamic> json) {
    return CategoryRefModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}

class GuestItemDetailModel {
  const GuestItemDetailModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.description,
    this.category,
    this.price,
    this.originalPrice,
    this.hasOffer = false,
    this.offerDiscountPercent,
    this.offerStartsAt,
    this.offerEndsAt,
    this.image,
  });

  final int id;
  final int tenantId;
  final String name;
  final String slug;
  final String description;
  final CategoryRefModel? category;
  final PriceModel? price;
  final PriceModel? originalPrice;
  final bool hasOffer;
  final int? offerDiscountPercent;
  final DateTime? offerStartsAt;
  final DateTime? offerEndsAt;
  final String? image;

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static num? _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static DateTime? _asDateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static int? _deriveDiscountPercent({
    required Map<String, dynamic>? activeOffer,
    required PriceModel? finalPrice,
    required PriceModel? originalPrice,
  }) {
    if (activeOffer != null) {
      final discountType = (activeOffer['discount_type'] ?? '').toString().trim().toLowerCase();
      final discountValue = _asNum(activeOffer['discount_value']);
      if (discountType == 'percentage' && discountValue != null && discountValue > 0) {
        return discountValue.round().clamp(1, 100);
      }
    }

    if (finalPrice != null && originalPrice != null && originalPrice.amount > 0 && finalPrice.amount < originalPrice.amount) {
      final percent = ((1 - (finalPrice.amount / originalPrice.amount)) * 100).round();
      return percent.clamp(1, 100);
    }

    return null;
  }

  factory GuestItemDetailModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final categoryModel = categoryJson is Map
        ? CategoryRefModel.fromJson(Map<String, dynamic>.from(categoryJson))
        : null;

    final finalPriceJson =
      json['final_price'] ?? json['price'] ?? json['active_price'];
    final originalPriceJson = json['price'] ?? json['active_price'];
    final finalPriceModel = finalPriceJson is Map
      ? PriceModel.fromJson(Map<String, dynamic>.from(finalPriceJson))
      : null;
    final originalPriceModel = originalPriceJson is Map
      ? PriceModel.fromJson(Map<String, dynamic>.from(originalPriceJson))
        : null;
    final activeOfferRaw = json['active_offer'];
    final activeOffer = activeOfferRaw is Map
        ? Map<String, dynamic>.from(activeOfferRaw)
        : null;
    final offerStartsAt = _asDateTime(activeOffer?['starts_at']);
    final offerEndsAt = _asDateTime(activeOffer?['ends_at']);
    final offerDiscountPercent = _deriveDiscountPercent(
      activeOffer: activeOffer,
      finalPrice: finalPriceModel,
      originalPrice: originalPriceModel,
    );
    final hasOffer =
      _asBool(json['has_offer']) ||
      offerDiscountPercent != null ||
      (finalPriceModel != null &&
        originalPriceModel != null &&
        finalPriceModel.amount < originalPriceModel.amount);

    return GuestItemDetailModel(
      id: _asInt(json['id']),
      tenantId: _asInt(json['tenant_id']),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: json['description'] as String? ?? '',
      category: categoryModel,
      price: finalPriceModel,
      originalPrice: originalPriceModel,
      hasOffer: hasOffer,
      offerDiscountPercent: offerDiscountPercent,
      offerStartsAt: offerStartsAt,
      offerEndsAt: offerEndsAt,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'slug': slug,
    'description': description,
    if (category != null) 'category': category!.toJson(),
    if (price != null) 'price': price!.toJson(),
    if (originalPrice != null) 'original_price': originalPrice!.toJson(),
    'has_offer': hasOffer,
    if (offerDiscountPercent != null) 'offer_discount_percent': offerDiscountPercent,
    if (offerStartsAt != null) 'offer_starts_at': offerStartsAt!.toIso8601String(),
    if (offerEndsAt != null) 'offer_ends_at': offerEndsAt!.toIso8601String(),
    if (image != null) 'image': image,
  };
}
