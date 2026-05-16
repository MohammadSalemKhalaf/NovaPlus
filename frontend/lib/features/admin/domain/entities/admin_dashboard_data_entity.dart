class AdminDashboardDataEntity {
  const AdminDashboardDataEntity({
    required this.totalStores,
    required this.totalOwners,
    required this.activeSubscriptions,
    required this.revenue,
    required this.weeklyStoresActivity,
    required this.weeklyOwnersActivity,
    required this.monthlyStoresActivity,
    required this.monthlyOwnersActivity,
    required this.businessTypeDistribution,
  });

  final int totalStores;
  final int totalOwners;
  final int activeSubscriptions;
  final double revenue;
  final List<int> weeklyStoresActivity;
  final List<int> weeklyOwnersActivity;
  final List<int> monthlyStoresActivity;
  final List<int> monthlyOwnersActivity;
  final List<BusinessTypeDistributionEntity> businessTypeDistribution;
}

class BusinessTypeDistributionEntity {
  const BusinessTypeDistributionEntity({
    required this.name,
    required this.count,
  });

  final String name;
  final int count;
}
