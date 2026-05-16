import '../entities/guest_entities.dart';

abstract class GuestRepository {
  Future<List<GuestStoreEntity>> listStores({
    String? search,
    int? businessTypeId,
    int perPage,
  });

  Future<GuestStoreDetailEntity> getStoreBySlug(String slug);

  Future<List<GuestCategoryEntity>> getCategoriesForTenant(
    int tenantId, {
    int perPage,
  });

  Future<List<GuestItemListEntity>> getItemsForTenant(
    int tenantId, {
    int? categoryId,
    String? search,
    int perPage,
  });

  Future<GuestItemDetailEntity> getItemDetail(int tenantId, int itemId);
}
