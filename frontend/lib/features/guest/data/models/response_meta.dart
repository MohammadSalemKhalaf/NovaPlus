class PaginationMeta {
  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] as int,
      lastPage: json['last_page'] as int,
      perPage: json['per_page'] as int,
      total: json['total'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'current_page': currentPage,
    'last_page': lastPage,
    'per_page': perPage,
    'total': total,
  };
}

class ResponseMeta {
  const ResponseMeta({
    this.pagination,
  });

  final PaginationMeta? pagination;

  factory ResponseMeta.fromJson(Map<String, dynamic> json) {
    final paginationJson = json['pagination'];
    final paginationMeta = paginationJson is Map
        ? PaginationMeta.fromJson(Map<String, dynamic>.from(paginationJson))
        : null;

    return ResponseMeta(
      pagination: paginationMeta,
    );
  }

  Map<String, dynamic> toJson() => {
    if (pagination != null) 'pagination': pagination!.toJson(),
  };
}
