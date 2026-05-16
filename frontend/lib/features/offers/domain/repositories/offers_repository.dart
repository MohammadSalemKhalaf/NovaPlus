import '../entities/offer_entity.dart';

abstract interface class OffersRepository {
  Future<List<OfferEntity>> getOffers({
    String? search,
    String? status,
    int perPage,
  });

  Future<OfferEntity> createOffer({
    required String title,
    String? description,
    String? image,
    String? discountType,
    num? discountValue,
    String? startsAt,
    String? endsAt,
    required String status,
    List<int>? itemIds,
  });

  Future<OfferEntity> updateOffer({
    required int id,
    String? title,
    String? description,
    String? image,
    String? discountType,
    num? discountValue,
    String? startsAt,
    String? endsAt,
    String? status,
    List<int>? itemIds,
  });

  Future<void> deleteOffer(int id);
}