import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';
import '../components/section_card.dart';
import '../components/input_decoration.dart';
import '../utils/currency_formatter.dart';

class BillTotalSection extends StatelessWidget {
  const BillTotalSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final showAlcoholTax = billData.useDifferentTipForAlcohol;

    return SectionCard(
      title: 'Bill Total',
      icon: Icons.receipt_long,
      children: [
        // Subtotal field with premium styling
        TextFormField(
          controller: billData.subtotalController,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Subtotal',
            prefixText: '\$',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [CurrencyFormatter.currencyFormatter],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 16),

        // Tax field with premium styling
        TextFormField(
          controller: billData.taxController,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Tax',
            prefixText: '\$',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [CurrencyFormatter.currencyFormatter],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),

        if (showAlcoholTax) ...[
          const SizedBox(height: 16),

          TextFormField(
            controller: billData.alcoholTaxController,
            decoration: AppInputDecoration.buildInputDecoration(
              context: context,
              labelText: 'Alcohol Tax',
              prefixText: '\$',
              hintText: '0.00',
              prefixIcon: Icons.local_bar,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyFormatter.currencyFormatter],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
