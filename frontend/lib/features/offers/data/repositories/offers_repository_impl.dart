import '../../domain/entities/offer_entity.dart';
import '../../domain/repositories/offers_repository.dart';
import '../datasources/offers_remote_data_source.dart';

class OffersRepositoryImpl implements OffersRepository {
  OffersRepositoryImpl({required OffersRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final OffersRemoteDataSource _remoteDataSource;

  @override
  Future<List<OfferEntity>> getOffers({
    String? search,
    String? status,
    int perPage = 100,
  }) async {
    final offers = await _remoteDataSource.getOffers(
      search: search,
      status: status,
      perPage: perPage,
    );

    return offers.map((offer) => offer.toEntity()).toList(growable: false);
  }

  @override
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
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'status': status,
      if (description != null) 'description': description,
      if (image != null) 'image': image,
      if (discountType != null) 'discount_type': discountType,
      if (discountValue != null) 'discount_value': discountValue,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (itemIds != null) 'item_ids': itemIds,
    };

    final offer = await _remoteDataSource.createOffer(payload);
    return offer.toEntity();
  }

  @override
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
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (image != null) 'image': image,
      if (discountType != null) 'discount_type': discountType,
      if (discountValue != null) 'discount_value': discountValue,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (status != null) 'status': status,
      if (itemIds != null) 'item_ids': itemIds,
    };

    final offer = await _remoteDataSource.updateOffer(id: id, payload: payload);
    return offer.toEntity();
  }

  @override
  Future<void> deleteOffer(int id) {
    return _remoteDataSource.deleteOffer(id);
  }
}