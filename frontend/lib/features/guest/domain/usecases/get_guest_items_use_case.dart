import '../entities/guest_entities.dart';
import '../repositories/guest_repository.dart';

class GetGuestItemsUseCase {
  GetGuestItemsUseCase(this._repository);

  final GuestRepository _repository;

  Future<List<GuestItemListEntity>> call(
    int tenantId, {
    int? categoryId,
    String? search,
    int perPage = 15,
  }) {
    return _repository.getItemsForTenant(
      tenantId,
      categoryId: categoryId,
      search: search,
      perPage: perPage,
    );
  }
}
