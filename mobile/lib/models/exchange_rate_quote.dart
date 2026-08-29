class ExchangeRateQuote {
  final String currencyCode;
  final double usdRate;
  final String rateDate;
  final String source;

  const ExchangeRateQuote({
    required this.currencyCode,
    required this.usdRate,
    required this.rateDate,
    required this.source,
  });

  const ExchangeRateQuote.usd()
    : currencyCode = 'USD',
      usdRate = 1,
      rateDate = '',
      source = 'native-usd';

  factory ExchangeRateQuote.fromJson(Map<String, dynamic> json) {
    return ExchangeRateQuote(
      currencyCode: (json['base'] as String? ?? '').toUpperCase(),
      usdRate: (json['rate'] as num?)?.toDouble() ?? 0,
      rateDate: json['date'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  bool get isValid =>
      currencyCode.length == 3 &&
      usdRate.isFinite &&
      usdRate > 0 &&
      source.isNotEmpty &&
      (currencyCode == 'USD' || rateDate.isNotEmpty);

  double convertToUSD(double originalAmount) =>
      (originalAmount * usdRate * 100).roundToDouble() / 100;
}
