import '../entities/guest_entities.dart';
import '../repositories/guest_repository.dart';

class ListGuestStoresUseCase {
  ListGuestStoresUseCase(this._repository);

  final GuestRepository _repository;

  Future<List<GuestStoreEntity>> call({
    String? search,
    int? businessTypeId,
    int perPage = 10,
  }) {
    return _repository.listStores(
      search: search,
      businessTypeId: businessTypeId,
      perPage: perPage,
    );
  }
}
