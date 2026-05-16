class SetActivePriceRequestModel {
  const SetActivePriceRequestModel({
    required this.currencyCode,
    required this.basePriceAmount,
    required this.compareAtPriceAmount,
    required this.effectiveFrom,
    required this.effectiveTo,
  });

  final String currencyCode;
  final String basePriceAmount;
  final String? compareAtPriceAmount;
  final String effectiveFrom;
  final String? effectiveTo;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currency_code': currencyCode,
      'base_price_amount': basePriceAmount,
      'compare_at_price_amount': compareAtPriceAmount,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
    };
  }
}
