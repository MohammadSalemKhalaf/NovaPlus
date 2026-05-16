import '../entities/create_item_input_entity.dart';
import '../entities/create_item_result_entity.dart';
import '../entities/item_entity.dart';
import '../entities/set_active_price_input_entity.dart';
import '../entities/set_active_price_result_entity.dart';
import '../entities/upload_item_image_input_entity.dart';
import '../entities/upload_item_image_result_entity.dart';

abstract class ItemsRepository {
  Future<List<ItemEntity>> getItems({
    String? search,
    int? categoryId,
  });

  Future<CreateItemResultEntity> createItem(CreateItemInputEntity input);

  Future<UploadItemImageResultEntity> uploadItemImage(UploadItemImageInputEntity input);

  Future<SetActivePriceResultEntity> setActivePrice(SetActivePriceInputEntity input);

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
  });

  Future<void> deleteItem(int id);
}
