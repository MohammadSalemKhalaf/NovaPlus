import 'item_model.dart';

class ItemsResponseModel {
  const ItemsResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.meta,
  });

  final bool success;
  final String message;
  final List<ItemModel> data;
  final ItemsMetaModel meta;

  factory ItemsResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = _extractItems(json['data']);
    final dataList = rawData is List
        ? rawData
            .whereType<Map>()
            .map((item) => ItemModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ItemModel>[];

    return ItemsResponseModel(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? '',
      data: dataList,
      meta: ItemsMetaModel.fromJson(json['meta']),
    );
  }

  static dynamic _extractItems(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List) {
        return map['items'];
      }
    }

    return null;
  }
}

class ItemsMetaModel {
  const ItemsMetaModel({this.pagination});

  final ItemsPaginationModel? pagination;

  factory ItemsMetaModel.fromJson(dynamic json) {
    if (json is! Map) {
      return const ItemsMetaModel();
    }

    final map = Map<String, dynamic>.from(json);
    return ItemsMetaModel(
      pagination: ItemsPaginationModel.fromJson(map['pagination']),
    );
  }
}

class ItemsPaginationModel {
  const ItemsPaginationModel({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  factory ItemsPaginationModel.fromJson(dynamic json) {
    if (json is! Map) {
      return const ItemsPaginationModel(
        currentPage: 1,
        lastPage: 1,
        perPage: 0,
        total: 0,
      );
    }

    final map = Map<String, dynamic>.from(json);
    return ItemsPaginationModel(
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      perPage: (map['per_page'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}
