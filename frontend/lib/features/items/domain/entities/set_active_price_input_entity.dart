class SetActivePriceInputEntity {
  const SetActivePriceInputEntity({
    required this.itemId,
    required this.currencyCode,
    required this.basePriceAmount,
    required this.compareAtPriceAmount,
    required this.effectiveFrom,
    required this.effectiveTo,
  });

  final int itemId;
  final String currencyCode;
  final String basePriceAmount;
  final String? compareAtPriceAmount;
  final String effectiveFrom;
  final String? effectiveTo;
}
