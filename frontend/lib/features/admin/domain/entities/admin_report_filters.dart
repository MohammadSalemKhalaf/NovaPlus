class StoresFilter {
  const StoresFilter({
    this.search,
    this.businessType,
    this.businessTypeId,
    this.page = 1,
    this.perPage = 20,
  });

  final String? search;
  // Backward-compatibility field for running hot-reload sessions.
  // Filtering must rely on businessTypeId.
  final String? businessType;
  final int? businessTypeId;
  final int page;
  final int perPage;

  StoresFilter copyWith({
    Object? search = _storesFilterUnset,
    Object? businessType = _storesFilterUnset,
    Object? businessTypeId = _storesFilterUnset,
    int? page,
    int? perPage,
  }) {
    return StoresFilter(
      search: identical(search, _storesFilterUnset) ? this.search : search as String?,
      businessType: identical(businessType, _storesFilterUnset)
          ? this.businessType
          : businessType as String?,
      businessTypeId: identical(businessTypeId, _storesFilterUnset)
          ? this.businessTypeId
          : businessTypeId as int?,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'search': search?.trim(),
      'business_type_id': businessTypeId,
    };
    query.removeWhere((key, value) => value == null || (value is String && value.isEmpty));
    return query;
  }

  static const StoresFilter initial = StoresFilter();
}

const Object _storesFilterUnset = Object();

class SubscriptionFilter {
  const SubscriptionFilter({
    this.storeName,
    this.agentId,
    this.status,
    this.page = 1,
    this.perPage = 20,
  });

  final String? storeName;
  final int? agentId;
  final String? status;
  final int page;
  final int perPage;

  SubscriptionFilter copyWith({
    String? storeName,
    int? agentId,
    String? status,
    int? page,
    int? perPage,
  }) {
    return SubscriptionFilter(
      storeName: storeName ?? this.storeName,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'store_name': storeName?.trim(),
      'created_by_agent_id': agentId,
      'status': status?.trim(),
    };
    query.removeWhere((key, value) => value == null || (value is String && value.isEmpty));
    return query;
  }

  static const SubscriptionFilter initial = SubscriptionFilter();
}

class UsersFilter {
  const UsersFilter({
    this.search,
    this.role,
    this.agentId,
    this.perPage = 20,
  });

  final String? search;
  final String? role;
  final int? agentId;
  final int perPage;

  UsersFilter copyWith({
    String? search,
    String? role,
    int? agentId,
    int? perPage,
  }) {
    return UsersFilter(
      search: search ?? this.search,
      role: role ?? this.role,
      agentId: agentId ?? this.agentId,
      perPage: perPage ?? this.perPage,
    );
  }

  static const UsersFilter initial = UsersFilter();
}
