class SalesAgentOnboardingResultEntity {
  const SalesAgentOnboardingResultEntity({
    required this.ownerUserId,
    required this.tenantId,
    required this.email,
  });

  final int ownerUserId;
  final int tenantId;
  final String email;
}
