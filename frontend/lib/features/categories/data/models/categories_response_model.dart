import 'category_model.dart';

class CategoriesResponseModel {
  const CategoriesResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.meta,
  });

  final bool success;
  final String message;
  final List<CategoryModel> data;
  final CategoriesMetaModel meta;

  factory CategoriesResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = _extractCategoryList(json['data']);
    final dataList = rawData is List
        ? rawData
            .whereType<Map>()
            .map((item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <CategoryModel>[];

    return CategoriesResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataList,
      meta: CategoriesMetaModel.fromJson(json['meta']),
    );
  }

  static dynamic _extractCategoryList(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nestedCategories = map['categories'];
      if (nestedCategories is List) {
        return nestedCategories;
      }
    }

    return null;
  }
}

class CategoriesMetaModel {
  const CategoriesMetaModel({this.pagination});

  final CategoriesPaginationModel? pagination;

  factory CategoriesMetaModel.fromJson(dynamic json) {
    if (json is! Map) {
      return const CategoriesMetaModel();
    }

    final map = Map<String, dynamic>.from(json);
    return CategoriesMetaModel(
      pagination: CategoriesPaginationModel.fromJson(map['pagination']),
    );
  }
}

class CategoriesPaginationModel {
  const CategoriesPaginationModel({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  factory CategoriesPaginationModel.fromJson(dynamic json) {
    if (json is! Map) {
      return const CategoriesPaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 0,
        total: 0,
      );
    }

    final map = Map<String, dynamic>.from(json);
    return CategoriesPaginationModel(
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      perPage: (map['per_page'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}
