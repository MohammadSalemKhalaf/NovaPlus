import '../../domain/entities/create_item_input_entity.dart';
import '../../domain/entities/create_item_result_entity.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/entities/set_active_price_input_entity.dart';
import '../../domain/entities/set_active_price_result_entity.dart';
import '../../domain/entities/upload_item_image_input_entity.dart';
import '../../domain/entities/upload_item_image_result_entity.dart';
import '../../domain/repositories/items_repository.dart';
import '../datasources/items_remote_data_source.dart';
import '../models/create_item_request_model.dart';
import '../models/set_active_price_request_model.dart';
import '../models/upload_item_image_request_model.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  ItemsRepositoryImpl({required ItemsRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final ItemsRemoteDataSource _remoteDataSource;

  @override
  Future<List<ItemEntity>> getItems({
    String? search,
    int? categoryId,
  }) async {
    final response = await _remoteDataSource.getItems(
      search: search,
      categoryId: categoryId,
    );

    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to fetch items');
    }

    return response.data
        .map(
          (item) => ItemEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
            status: item.status,
            description: item.description,
            shortDescription: item.shortDescription,
            longDescription: item.longDescription,
            categoryId: item.categoryId,
            image: item.image,
            price: item.priceAmount,
            currency: item.currencyCode,
            primaryImage: item.primaryImage == null
                ? null
                : ItemPrimaryImageEntity(
                    id: item.primaryImage!.id,
                    url: item.primaryImage!.url,
                  ),
            prices: item.prices
                .map(
                  (price) => ItemPriceEntity(
                    basePriceAmount: price.basePriceAmount,
                    currencyCode: price.currencyCode,
                    pricingStatus: price.pricingStatus,
                    compareAtPriceAmount: price.compareAtPriceAmount,
                  ),
                )
                .toList(growable: false),
            images: item.images
                .map(
                  (image) => ItemImageEntity(
                    storagePath: image.storagePath,
                    altText: image.altText,
                    isPrimary: image.isPrimary,
                  ),
                )
                .toList(growable: false),
            offerIds: item.offerIds,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CreateItemResultEntity> createItem(CreateItemInputEntity input) async {
    final request = CreateItemRequestModel(
      categoryId: input.categoryId,
      name: input.name,
      slug: input.slug,
      shortDescription: input.shortDescription,
      longDescription: input.longDescription,
      itemType: input.itemType,
      status: input.status,
      visibility: input.visibility,
      primaryImageId: input.primaryImageId,
      sortOrder: input.sortOrder,
    );

    final response = await _remoteDataSource.createItem(request);
    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to create item');
    }

    return CreateItemResultEntity(
      success: response.success,
      message: response.message,
      itemId: response.itemId,
    );
  }

  @override
  Future<UploadItemImageResultEntity> uploadItemImage(UploadItemImageInputEntity input) async {
    final request = UploadItemImageRequestModel(
      itemId: input.itemId,
      imagePath: input.imagePath,
      altText: input.altText,
      sortOrder: input.sortOrder,
      isPrimary: input.isPrimary,
    );

    final response = await _remoteDataSource.uploadItemImage(request);
    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to upload image');
    }

    return UploadItemImageResultEntity(
      success: response.success,
      message: response.message,
      imageId: response.imageId,
      storagePath: response.storagePath,
    );
  }

  @override
  Future<SetActivePriceResultEntity> setActivePrice(SetActivePriceInputEntity input) async {
    final request = SetActivePriceRequestModel(
      currencyCode: input.currencyCode,
      basePriceAmount: input.basePriceAmount,
      compareAtPriceAmount: input.compareAtPriceAmount,
      effectiveFrom: input.effectiveFrom,
      effectiveTo: input.effectiveTo,
    );

    final response = await _remoteDataSource.setActivePrice(
      itemId: input.itemId,
      request: request,
    );

    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to set active price');
    }

    return SetActivePriceResultEntity(
      success: response.success,
      message: response.message,
      priceId: response.priceId,
    );
  }

  @override
  Future<void> updateItem({
    required int id,
    int? categoryId,
    String? name,
    String? slug,
    String? shortDescription,
    String? longDescription,
    String? itemType,
    String? status,
    String? visibility,
    int? primaryImageId,
    int? sortOrder,
    List<int>? offerIds,
  }) {
    final data = <String, dynamic>{};
    if (categoryId != null) data['category_id'] = categoryId;
    if (name != null) data['name'] = name;
    if (slug != null) data['slug'] = slug;
    if (shortDescription != null) data['short_description'] = shortDescription;
    if (longDescription != null) data['long_description'] = longDescription;
    if (itemType != null) data['item_type'] = itemType;
    if (status != null) data['status'] = status;
    if (visibility != null) data['visibility'] = visibility;
    if (primaryImageId != null) data['primary_image_id'] = primaryImageId;
    if (sortOrder != null) data['sort_order'] = sortOrder;
    if (offerIds != null) data['offer_ids'] = offerIds;

    return _remoteDataSource.updateItem(id: id, data: data);
  }

  @override
  Future<void> deleteItem(int id) {
    return _remoteDataSource.deleteItem(id);
  }
}
