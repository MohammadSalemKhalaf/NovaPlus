import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/categories_remote_data_source.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl({required CategoriesRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final CategoriesRemoteDataSource _remoteDataSource;

  @override
  Future<List<CategoryEntity>> getCategories() async {
    final response = await _remoteDataSource.getCategories();

    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to fetch categories');
    }

    return response.data
        .map(
          (item) => CategoryEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
            parentId: item.parentId,
            status: item.status,
            description: item.description,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CategoryEntity>> getCategoriesByStore(int storeId) async {
    final response = await _remoteDataSource.getCategoriesByStore(storeId);

    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to fetch categories');
    }

    return response.data
        .map(
          (item) => CategoryEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
            parentId: item.parentId,
            status: item.status,
            description: item.description,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CategoryEntity>> getPublicCategoriesByStore(int storeId) async {
    final response = await _remoteDataSource.getPublicCategoriesByStore(storeId);

    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to fetch categories');
    }

    return response.data
        .map(
          (item) => CategoryEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
            parentId: item.parentId,
            status: item.status,
            description: item.description,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> createCategory({
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  }) {
    return _remoteDataSource.createCategory(
      name: name,
      slug: slug,
      status: status,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> updateCategory({
    required int id,
    required String name,
    required String slug,
    required String status,
    required int sortOrder,
  }) {
    return _remoteDataSource.updateCategory(
      id: id,
      name: name,
      slug: slug,
      status: status,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> deleteCategory(int id) {
    return _remoteDataSource.deleteCategory(id);
  }
}
