// Spliq: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/quick_split/bill_entry/components/input_decoration.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/components/section_card.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// BillTotalSection - Input section for entering bill subtotal and tax amounts
///
/// Provides standardized text input fields for the primary bill values:
/// - Subtotal amount
/// - Tax amount
///
/// Features:
/// - Currency-formatted input with automatic validation
/// - Dollar sign prefix and decimal formatting
/// - Integrated with the BillData provider for automatic calculations
/// - Consistent styling with the rest of the application
///
/// This component automatically triggers bill recalculation when values change
/// through the controllers connected to the BillData provider.
class BillTotalSection extends StatelessWidget {
  const BillTotalSection({super.key});

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);

    return SectionCard(
      title: 'Bill Total',
      icon: Icons.receipt_long,
      children: [
        // Subtotal input field with currency formatting
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

        // Tax input field with currency formatting
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
      ],
    );
  }
}
