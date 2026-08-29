import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CurrencySection extends StatelessWidget {
  const CurrencySection({super.key});

  Future<void> _loadQuote(BillData data, String currency) async {
    data.selectCurrency(currency);
    if (currency == 'USD') return;
    data.setExchangeRateLoading();
    try {
      final quote = await ApiService().getExchangeRate(currency);
      if (data.currencyCode == currency) data.setExchangeRateQuote(quote);
    } on ApiException catch (error) {
      if (data.currencyCode == currency) {
        data.setExchangeRateError(error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillData>(
      builder: (context, data, _) {
        final theme = Theme.of(context);
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt currency',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The daily USD rate is frozen when this receipt is added.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: data.currencyCode,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      BillData.supportedCurrencies
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(),
                  onChanged:
                      data.isLoadingExchangeRate
                          ? null
                          : (currency) {
                            if (currency != null) {
                              _loadQuote(data, currency);
                            }
                          },
                ),
                if (data.isLoadingExchangeRate) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Loading today’s USD rate…'),
                ] else if (data.exchangeRateError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    data.exchangeRateError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  TextButton.icon(
                    onPressed: () => _loadQuote(data, data.currencyCode),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry rate'),
                  ),
                ] else if (data.currencyCode != 'USD' &&
                    data.hasUsableExchangeRate) ...[
                  const SizedBox(height: 12),
                  Text(
                    '1 ${data.currencyCode} = '
                    '${data.exchangeRateQuote.usdRate.toStringAsFixed(4)} USD '
                    '(${data.exchangeRateQuote.rateDate})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (data.total > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${data.currencyCode} ${data.total.toStringAsFixed(2)} = '
                      '\$${data.usdTotal.toStringAsFixed(2)} USD',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
