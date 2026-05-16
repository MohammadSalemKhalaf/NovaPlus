class PriceModel {
  const PriceModel({
    required this.amount,
    required this.currency,
  });

  final double amount;
  final String currency;

  factory PriceModel.fromJson(Map<String, dynamic> json) {
    final currency =
        (json['currency'] ?? json['currency_code'] ?? '').toString().trim();

    return PriceModel(
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0.0,
      currency: currency.isEmpty ? 'USD' : currency,
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
  };
}
