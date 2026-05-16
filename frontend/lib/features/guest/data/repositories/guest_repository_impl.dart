import '../../domain/entities/guest_entities.dart';
import '../../domain/repositories/guest_repository.dart';
import '../datasources/guest_remote_data_source.dart';

class GuestRepositoryImpl implements GuestRepository {
  GuestRepositoryImpl({required GuestRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final GuestRemoteDataSource _remoteDataSource;

  @override
  Future<List<GuestStoreEntity>> listStores({
    String? search,
    int? businessTypeId,
    int perPage = 10,
  }) async {
    final response = await _remoteDataSource.listStores(
      search: search,
      businessTypeId: businessTypeId,
      perPage: perPage,
    );

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty ? response.message : 'Failed to fetch stores',
      );
    }

    return response.data
        .map(
          (store) => GuestStoreEntity(
            id: store.id,
            name: store.name,
            slug: store.slug,
            image: store.image,
            businessType: store.businessType == null
                ? null
                : BusinessTypeEntity(
                    id: store.businessType!.id,
                    name: store.businessType!.name,
                    slug: store.businessType!.slug,
                  ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<GuestStoreDetailEntity> getStoreBySlug(String slug) async {
    final response = await _remoteDataSource.getStoreBySlug(slug);

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to fetch store details',
      );
    }

    final data = response.data;

    return GuestStoreDetailEntity(
      id: data.id,
      name: data.name,
      slug: data.slug,
      businessMode: data.businessMode,
      image: data.image,
      businessType: data.businessType == null
          ? null
          : BusinessTypeEntity(
              id: data.businessType!.id,
              name: data.businessType!.name,
              slug: data.businessType!.slug,
            ),
      catalogSummary: CatalogSummaryEntity(
        categoriesCount: data.catalogSummary.categoriesCount,
        publicItemsCount: data.catalogSummary.publicItemsCount,
      ),
    );
  }

  @override
  Future<List<GuestCategoryEntity>> getCategoriesForTenant(
    int tenantId, {
    int perPage = 15,
  }) async {
    final response = await _remoteDataSource.getCategoriesForTenant(
      tenantId,
      perPage: perPage,
    );

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to fetch categories',
      );
    }

    return response.data
        .map(
          (category) => GuestCategoryEntity(
            id: category.id,
            name: category.name,
            slug: category.slug,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<GuestItemListEntity>> getItemsForTenant(
    int tenantId, {
    int? categoryId,
    String? search,
    int perPage = 15,
  }) async {
    final response = await _remoteDataSource.getItemsForTenant(
      tenantId,
      categoryId: categoryId,
      search: search,
      perPage: perPage,
    );

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty ? response.message : 'Failed to fetch items',
      );
    }

    return response.data
        .map(
          (item) => GuestItemListEntity(
            id: item.id,
            name: item.name,
            price: item.price == null
                ? null
                : PriceEntity(
                    amount: item.price!.amount,
                    currency: item.price!.currency,
                  ),
            originalPrice: item.originalPrice == null
                ? null
                : PriceEntity(
                    amount: item.originalPrice!.amount,
                    currency: item.originalPrice!.currency,
                  ),
            hasOffer: item.hasOffer,
            offerDiscountPercent: item.offerDiscountPercent,
            offerStartsAt: item.offerStartsAt,
            offerEndsAt: item.offerEndsAt,
            image: item.image,
            category: item.category,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<GuestItemDetailEntity> getItemDetail(int tenantId, int itemId) async {
    final response = await _remoteDataSource.getItemDetail(tenantId, itemId);

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to fetch item details',
      );
    }

    final data = response.data;

    return GuestItemDetailEntity(
      id: data.id,
      tenantId: data.tenantId,
      name: data.name,
      slug: data.slug,
      description: data.description,
      category: data.category == null
          ? null
          : CategoryRefEntity(
              id: data.category!.id,
              name: data.category!.name,
            ),
      price: data.price == null
          ? null
          : PriceEntity(
              amount: data.price!.amount,
              currency: data.price!.currency,
            ),
      originalPrice: data.originalPrice == null
          ? null
          : PriceEntity(
              amount: data.originalPrice!.amount,
              currency: data.originalPrice!.currency,
            ),
      hasOffer: data.hasOffer,
      offerDiscountPercent: data.offerDiscountPercent,
      offerStartsAt: data.offerStartsAt,
      offerEndsAt: data.offerEndsAt,
      image: data.image,
    );
  }
}
