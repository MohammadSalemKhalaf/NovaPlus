class SalesAgentRedeemResultEntity {
  const SalesAgentRedeemResultEntity({
    required this.status,
    required this.raw,
  });

  final String status;
  final Map<String, dynamic> raw;
}
