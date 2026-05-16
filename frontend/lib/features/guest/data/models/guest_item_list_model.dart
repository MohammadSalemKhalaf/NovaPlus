import 'price_model.dart';

class GuestItemListModel {
  const GuestItemListModel({
    required this.id,
    required this.name,
    this.price,
    this.originalPrice,
    this.hasOffer = false,
    this.offerDiscountPercent,
    this.offerStartsAt,
    this.offerEndsAt,
    this.image,
    this.category,
  });

  final int id;
  final String name;
  final PriceModel? price;
  final PriceModel? originalPrice;
  final bool hasOffer;
  final int? offerDiscountPercent;
  final DateTime? offerStartsAt;
  final DateTime? offerEndsAt;
  final String? image;
  final String? category;

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static num? _asNum(dynamic value) {
    if (value is num) return value;
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed;
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

  static String? _asImage(Map<String, dynamic> json) {
    final direct = json['image']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final primaryImage = json['primary_image'];
    if (primaryImage is Map) {
      final storagePath = primaryImage['storage_path']?.toString().trim();
      if (storagePath != null && storagePath.isNotEmpty) {
        return storagePath;
      }
    }

    return null;
  }

  static String? _asCategory(Map<String, dynamic> json) {
    final category = json['category'];
    if (category is String) {
      final value = category.trim();
      return value.isEmpty ? null : value;
    }
    if (category is Map) {
      final value = category['name']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final fallback = json['category_name']?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return null;
  }

  factory GuestItemListModel.fromJson(Map<String, dynamic> json) {
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

    return GuestItemListModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      price: finalPriceModel,
      originalPrice: originalPriceModel,
      hasOffer: hasOffer,
      offerDiscountPercent: offerDiscountPercent,
      offerStartsAt: offerStartsAt,
      offerEndsAt: offerEndsAt,
      image: _asImage(json),
      category: _asCategory(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (price != null) 'price': price!.toJson(),
    if (originalPrice != null) 'original_price': originalPrice!.toJson(),
    'has_offer': hasOffer,
    if (offerDiscountPercent != null) 'offer_discount_percent': offerDiscountPercent,
    if (offerStartsAt != null) 'offer_starts_at': offerStartsAt!.toIso8601String(),
    if (offerEndsAt != null) 'offer_ends_at': offerEndsAt!.toIso8601String(),
    if (image != null) 'image': image,
    if (category != null) 'category': category,
  };
}
