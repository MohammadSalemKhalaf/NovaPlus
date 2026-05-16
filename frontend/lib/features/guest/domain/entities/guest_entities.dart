class BusinessTypeEntity {
  const BusinessTypeEntity({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;
}

class GuestStoreEntity {
  const GuestStoreEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    this.businessType,
  });

  final int id;
  final String name;
  final String slug;
  final String? image;
  final BusinessTypeEntity? businessType;
}

class CatalogSummaryEntity {
  const CatalogSummaryEntity({
    required this.categoriesCount,
    required this.publicItemsCount,
  });

  final int categoriesCount;
  final int publicItemsCount;
}

class GuestStoreDetailEntity {
  const GuestStoreDetailEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.businessMode,
    this.image,
    this.businessType,
    required this.catalogSummary,
  });

  final int id;
  final String name;
  final String slug;
  final String businessMode;
  final String? image;
  final BusinessTypeEntity? businessType;
  final CatalogSummaryEntity catalogSummary;
}

class GuestCategoryEntity {
  const GuestCategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;
}

class PriceEntity {
  const PriceEntity({
    required this.amount,
    required this.currency,
  });

  final double amount;
  final String currency;
}

class GuestItemListEntity {
  const GuestItemListEntity({
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
  final PriceEntity? price;
  final PriceEntity? originalPrice;
  final bool hasOffer;
  final int? offerDiscountPercent;
  final DateTime? offerStartsAt;
  final DateTime? offerEndsAt;
  final String? image;
  final String? category;
}

class CategoryRefEntity {
  const CategoryRefEntity({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class GuestItemDetailEntity {
  const GuestItemDetailEntity({
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
  final CategoryRefEntity? category;
  final PriceEntity? price;
  final PriceEntity? originalPrice;
  final bool hasOffer;
  final int? offerDiscountPercent;
  final DateTime? offerStartsAt;
  final DateTime? offerEndsAt;
  final String? image;
}
