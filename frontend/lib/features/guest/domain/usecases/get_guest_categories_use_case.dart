import '../entities/guest_entities.dart';
import '../repositories/guest_repository.dart';

class GetGuestCategoriesUseCase {
  GetGuestCategoriesUseCase(this._repository);

  final GuestRepository _repository;

  Future<List<GuestCategoryEntity>> call(
    int tenantId, {
    int perPage = 15,
  }) {
    return _repository.getCategoriesForTenant(
      tenantId,
      perPage: perPage,
    );
  }
}
