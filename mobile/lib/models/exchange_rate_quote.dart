// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
