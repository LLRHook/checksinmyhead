import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';

class CurrencyConversionPreview extends StatefulWidget {
  final double amount;
  final String fromCurrency;
  final String toCurrency;

  const CurrencyConversionPreview({
    super.key,
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
  });

  @override
  State<CurrencyConversionPreview> createState() =>
      _CurrencyConversionPreviewState();
}

class _CurrencyConversionPreviewState extends State<CurrencyConversionPreview> {
  late Future<double> _rateFuture;

  @override
  void initState() {
    super.initState();
    _rateFuture = _loadRate();
  }

  @override
  void didUpdateWidget(covariant CurrencyConversionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromCurrency != widget.fromCurrency ||
        oldWidget.toCurrency != widget.toCurrency) {
      _rateFuture = _loadRate();
    }
  }

  Future<double> _loadRate() {
    if (widget.fromCurrency == widget.toCurrency) return Future.value(1);
    return ApiService().getCurrencyRate(widget.fromCurrency, widget.toCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<double>(
      future: _rateFuture,
      builder: (context, snapshot) {
        final rate = snapshot.data;
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              snapshot.hasError
                  ? Text(
                    'Conversion preview unavailable. Your original ${widget.fromCurrency} amount will be preserved.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  )
                  : snapshot.connectionState != ConnectionState.done
                  ? const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading conversion rate…'),
                    ],
                  )
                  : Text(
                    '${CurrencyFormatter.formatCurrency(widget.amount, currencyCode: widget.fromCurrency)} ≈ ${CurrencyFormatter.formatCurrency(widget.amount * rate!, currencyCode: widget.toCurrency)}\n1 ${widget.fromCurrency} = ${rate.toStringAsFixed(6)} ${widget.toCurrency}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        );
      },
    );
  }
}
