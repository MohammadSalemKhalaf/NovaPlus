import '../../domain/entities/store_entity.dart';
import '../../domain/repositories/stores_repository.dart';
import '../datasources/stores_remote_data_source.dart';

class StoresRepositoryImpl implements StoresRepository {
  StoresRepositoryImpl({required StoresRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final StoresRemoteDataSource _remoteDataSource;

  @override
  Future<List<StoreEntity>> getStores({
    String? search,
    int? businessTypeId,
  }) async {
    final response = await _remoteDataSource.getStores(
      search: search,
      businessTypeId: businessTypeId,
    );

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty ? response.message : 'Failed to fetch stores',
      );
    }

    return response.data
        .map(
          (item) => StoreEntity(
            id: item.id,
            tenantId: item.tenantId,
            name: item.name,
            slug: item.slug,
            businessTypeId: item.businessTypeId,
            businessTypeName: item.businessTypeName,
            businessTypeSlug: item.businessTypeSlug,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<StoreEntity?> getStoreBySlug(String slug) async {
    final item = await _remoteDataSource.getStoreBySlug(slug);
    if (item == null) {
      return null;
    }

    return StoreEntity(
      id: item.id,
      tenantId: item.tenantId,
      name: item.name,
      slug: item.slug,
      businessTypeId: item.businessTypeId,
      businessTypeName: item.businessTypeName,
      businessTypeSlug: item.businessTypeSlug,
    );
  }
}
