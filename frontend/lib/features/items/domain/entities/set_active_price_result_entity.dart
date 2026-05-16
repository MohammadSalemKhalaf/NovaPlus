class SetActivePriceResultEntity {
  const SetActivePriceResultEntity({
    required this.success,
    required this.message,
    this.priceId,
  });

  final bool success;
  final String message;
  final int? priceId;
}
