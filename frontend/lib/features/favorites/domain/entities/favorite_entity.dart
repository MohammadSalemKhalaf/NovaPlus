class FavoriteEntity {
  const FavoriteEntity({
    required this.tenantId,
    this.notificationsOptIn = false,
  });

  final String tenantId;
  final bool notificationsOptIn;
}
