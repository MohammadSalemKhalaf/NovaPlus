class CatalogSummaryModel {
  const CatalogSummaryModel({
    required this.categoriesCount,
    required this.publicItemsCount,
  });

  final int categoriesCount;
  final int publicItemsCount;

  factory CatalogSummaryModel.fromJson(Map<String, dynamic> json) {
    return CatalogSummaryModel(
      categoriesCount: json['categories_count'] as int,
      publicItemsCount: json['public_items_count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'categories_count': categoriesCount,
    'public_items_count': publicItemsCount,
  };
}
