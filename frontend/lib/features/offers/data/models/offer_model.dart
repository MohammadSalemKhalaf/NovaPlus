import '../../domain/entities/offer_entity.dart';

class OfferModel {
  const OfferModel({
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

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: _toInt(json['id']),
      tenantId: _toInt(json['tenant_id']),
      title: (json['title']?.toString() ?? '').trim(),
      description: _toNullableString(json['description']),
      image: _toNullableString(json['image']),
      discountType: _toNullableString(json['discount_type']),
      discountValue: _toNullableNum(json['discount_value']),
      startsAt: _toNullableDateTime(json['starts_at']),
      endsAt: _toNullableDateTime(json['ends_at']),
      status: (json['status']?.toString() ?? '').trim(),
      createdBy: _toInt(json['created_by']),
      itemIds: _toIntList(json['item_ids']),
      createdAt: _toNullableDateTime(json['created_at']),
      updatedAt: _toNullableDateTime(json['updated_at']),
    );
  }

  OfferEntity toEntity() {
    return OfferEntity(
      id: id,
      tenantId: tenantId,
      title: title,
      description: description,
      image: image,
      discountType: discountType,
      discountValue: discountValue,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status,
      createdBy: createdBy,
      itemIds: itemIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static num? _toNullableNum(dynamic value) {
    if (value is num) {
      return value;
    }

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return num.tryParse(text);
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static List<int> _toIntList(dynamic value) {
    if (value is! List) {
      return const <int>[];
    }

    return value
        .map((entry) {
          if (entry is int) {
            return entry;
          }
          return int.tryParse(entry?.toString() ?? '') ?? 0;
        })
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
  }
}