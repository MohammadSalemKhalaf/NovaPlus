import 'package:flutter/foundation.dart';

class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    this.description,
    this.shortDescription,
    this.longDescription,
    this.categoryId,
    this.image,
    this.priceAmount,
    this.currencyCode,
    required this.prices,
    required this.images,
    required this.offerIds,
    this.primaryImage,
    this.price,
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
  final double? priceAmount;
  final String? currencyCode;
  final List<ItemPriceModel> prices;
  final List<ItemImageModel> images;
  final List<int> offerIds;
  final ItemPrimaryImageModel? primaryImage;
  final ItemPriceModel? price;

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    debugPrint('ITEM RAW: $json');

    final shortDescription = json['short_description'] as String?;
    final longDescription = json['long_description'] as String?;
    final description = (json['description'] as String?) ??
        shortDescription ??
        longDescription;

    final int? categoryId;
    if (json['category_id'] is num) {
      categoryId = (json['category_id'] as num).toInt();
    } else {
      final category = json['category'];
      if (category is Map && category['id'] is num) {
        categoryId = (category['id'] as num).toInt();
      } else {
        categoryId = null;
      }
    }

    final prices = _readPrices(json);
    final images = _readImages(json);
    final primaryImage = _readPrimaryImage(json);
    final compactPrice = _readCompactPrice(json);
    final amountText = compactPrice?.basePriceAmount;
    final parsedAmount = amountText == null ? null : double.tryParse(amountText);

    final idRaw = json['id'];
    final itemId = idRaw is num ? idRaw.toInt() : int.tryParse('${idRaw ?? ''}') ?? 0;

    return ItemModel(
      id: itemId,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      description: description,
      shortDescription: shortDescription,
      longDescription: longDescription,
      categoryId: categoryId,
      image: primaryImage?.storagePath,
      priceAmount: parsedAmount,
      currencyCode: compactPrice?.currencyCode,
      prices: prices,
      images: images,
      offerIds: _readOfferIds(json),
      primaryImage: primaryImage,
      price: compactPrice,
    );
  }

  static List<int> _readOfferIds(Map<String, dynamic> json) {
    final offersRaw = json['offers'];
    if (offersRaw is! List) {
      return const <int>[];
    }

    return offersRaw
        .whereType<Map>()
        .map((offer) {
          final id = offer['id'];
          if (id is int) {
            return id;
          }
          return int.tryParse('${id ?? ''}') ?? 0;
        })
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
  }

  static ItemPriceModel? _readCompactPrice(Map<String, dynamic> json) {
    final finalPriceRaw = json['final_price'];
    if (finalPriceRaw is Map) {
      return ItemPriceModel.fromCompactJson(Map<String, dynamic>.from(finalPriceRaw));
    }

    final compactPriceRaw = json['price'];
    if (compactPriceRaw is Map) {
      return ItemPriceModel.fromCompactJson(Map<String, dynamic>.from(compactPriceRaw));
    }

    if (json['active_price'] is Map) {
      return ItemPriceModel.fromJson(Map<String, dynamic>.from(json['active_price'] as Map));
    }

    if (json['prices'] is List) {
      final pricesRaw = json['prices'] as List;
      for (final entry in pricesRaw) {
        if (entry is Map) {
          return ItemPriceModel.fromJson(Map<String, dynamic>.from(entry));
        }
      }
    }

    return null;
  }

  static ItemPrimaryImageModel? _readPrimaryImage(Map<String, dynamic> json) {
    final primaryImageRaw = json['primary_image'];
    if (primaryImageRaw is Map) {
      return ItemPrimaryImageModel.fromJson(Map<String, dynamic>.from(primaryImageRaw));
    }

    final compactImageRaw = json['image'];
    if (compactImageRaw is String && compactImageRaw.isNotEmpty) {
      return ItemPrimaryImageModel(
        id: null,
        url: compactImageRaw,
        storagePath: compactImageRaw,
      );
    }

    return null;
  }

  static List<ItemPriceModel> _readPrices(Map<String, dynamic> json) {
    final pricesRaw = json['prices'];
    if (pricesRaw is List) {
      return pricesRaw
          .whereType<Map>()
          .map((item) => ItemPriceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final activePriceRaw = json['active_price'];
    if (activePriceRaw is Map) {
      return <ItemPriceModel>[
        ItemPriceModel.fromJson(Map<String, dynamic>.from(activePriceRaw)),
      ];
    }

    final compactPriceRaw = json['price'];
    if (compactPriceRaw is Map) {
      return <ItemPriceModel>[
        ItemPriceModel.fromCompactJson(Map<String, dynamic>.from(compactPriceRaw)),
      ];
    }

    return const <ItemPriceModel>[];
  }

  static List<ItemImageModel> _readImages(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    if (imagesRaw is List) {
      return imagesRaw
          .whereType<Map>()
          .map((item) => ItemImageModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final primaryImageRaw = json['primary_image'];
    if (primaryImageRaw is Map) {
      return <ItemImageModel>[
        ItemImageModel.fromJson(Map<String, dynamic>.from(primaryImageRaw)),
      ];
    }

    final compactImageRaw = json['image'];
    if (compactImageRaw is String && compactImageRaw.isNotEmpty) {
      return <ItemImageModel>[ItemImageModel(storagePath: compactImageRaw)];
    }

    return const <ItemImageModel>[];
  }
}

class ItemPriceModel {
  const ItemPriceModel({
    this.basePriceAmount,
    this.currencyCode,
    this.pricingStatus,
    this.compareAtPriceAmount,
  });

  final String? basePriceAmount;
  final String? currencyCode;
  final String? pricingStatus;
  final String? compareAtPriceAmount;

  factory ItemPriceModel.fromJson(Map<String, dynamic> json) {
    return ItemPriceModel(
      basePriceAmount: json['base_price_amount']?.toString() ?? json['amount']?.toString(),
      currencyCode: (json['currency_code'] ?? json['currency'])?.toString(),
      pricingStatus: json['pricing_status'] as String?,
      compareAtPriceAmount: json['compare_at_price_amount']?.toString(),
    );
  }

  factory ItemPriceModel.fromCompactJson(Map<String, dynamic> json) {
    return ItemPriceModel(
      basePriceAmount: json['amount']?.toString() ?? json['base_price_amount']?.toString(),
      currencyCode: (json['currency'] ?? json['currency_code'])?.toString(),
      pricingStatus: 'active',
      compareAtPriceAmount: null,
    );
  }
}

class ItemImageModel {
  const ItemImageModel({
    required this.storagePath,
    this.altText,
    this.isPrimary,
  });

  final String storagePath;
  final String? altText;
  final bool? isPrimary;

  factory ItemImageModel.fromJson(Map<String, dynamic> json) {
    return ItemImageModel(
      storagePath: (json['storage_path'] as String?) ?? '',
      altText: json['alt_text'] as String?,
      isPrimary: json['is_primary'] as bool?,
    );
  }
}

class ItemPrimaryImageModel {
  const ItemPrimaryImageModel({
    required this.id,
    required this.url,
    required this.storagePath,
  });

  final int? id;
  final String url;
  final String? storagePath;

  factory ItemPrimaryImageModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final storagePath = (json['storage_path'] as String?)?.trim();
    final url = ((json['url'] as String?) ?? storagePath ?? '').trim();

    return ItemPrimaryImageModel(
      id: idRaw is num ? idRaw.toInt() : null,
      url: url,
      storagePath: storagePath,
    );
  }
}
