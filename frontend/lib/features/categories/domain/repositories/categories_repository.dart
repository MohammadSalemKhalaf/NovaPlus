import '../entities/category_entity.dart';

abstract class CategoriesRepository {
  Future<List<CategoryEntity>> getCategories();

  Future<List<CategoryEntity>> getCategoriesByStore(int storeId);

  /// Get public categories for a store (no authentication needed)
  /// Returns empty list if no categories, throws Exception on error
  Future<List<CategoryEntity>> getPublicCategoriesByStore(int storeId);

  Future<void> createCategory({
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  });

  Future<void> updateCategory({
    required int id,
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  });

  Future<void> deleteCategory(int id);
}
