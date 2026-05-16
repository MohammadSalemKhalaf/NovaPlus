import '../entities/guest_entities.dart';
import '../repositories/guest_repository.dart';

class GetGuestStoreDetailsUseCase {
  GetGuestStoreDetailsUseCase(this._repository);

  final GuestRepository _repository;

  Future<GuestStoreDetailEntity> call(String slug) {
    return _repository.getStoreBySlug(slug);
  }
}
