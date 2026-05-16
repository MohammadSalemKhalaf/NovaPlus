class ItemEntity {
  const ItemEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    this.description,
    this.shortDescription,
    this.longDescription,
    this.categoryId,
    this.image,
    this.price,
    this.currency,
    required this.prices,
    required this.images,
    required this.offerIds,
    this.primaryImage,
  });

  final int id;
  final String name;
  final String slug;
  final String status;
  final String? description;
  final String? shortDescription;
  final String? longDescription;
  final int? categoryId;
  final String? image;
  final double? price;
  final String? currency;
  final List<ItemPriceEntity> prices;
  final List<ItemImageEntity> images;
  final List<int> offerIds;
  final ItemPrimaryImageEntity? primaryImage;
}

class ItemPriceEntity {
  const ItemPriceEntity({
    this.basePriceAmount,
    this.currencyCode,
    this.pricingStatus,
    this.compareAtPriceAmount,
  });

  final String? basePriceAmount;
  final String? currencyCode;
  final String? pricingStatus;
  final String? compareAtPriceAmount;
}

class ItemImageEntity {
  const ItemImageEntity({
    required this.storagePath,
    this.altText,
    this.isPrimary,
  });

  final String storagePath;
  final String? altText;
  final bool? isPrimary;
}

class ItemPrimaryImageEntity {
  const ItemPrimaryImageEntity({
    required this.id,
    required this.url,
  });

  final int? id;
  final String url;
}
