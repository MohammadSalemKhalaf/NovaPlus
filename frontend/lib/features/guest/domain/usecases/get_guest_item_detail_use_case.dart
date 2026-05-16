import '../entities/guest_entities.dart';
import '../repositories/guest_repository.dart';

class GetGuestItemDetailUseCase {
  GetGuestItemDetailUseCase(this._repository);

  final GuestRepository _repository;

  Future<GuestItemDetailEntity> call(int tenantId, int itemId) {
    return _repository.getItemDetail(tenantId, itemId);
  }
}
