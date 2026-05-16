import '../entities/store_entity.dart';

abstract class StoresRepository {
  Future<List<StoreEntity>> getStores({
    String? search,
    int? businessTypeId,
  });

  Future<StoreEntity?> getStoreBySlug(String slug);
}
