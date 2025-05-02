import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';
import '../utils/color_utils.dart';
import '../utils/calculation_utils.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final BillSummaryData data;

  const PersonCard({Key? key, required this.person, required this.data})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBirthdayPerson = data.birthdayPerson == person;

    // Get items assigned to this person
    final personItems =
        data.items
            .where((item) => (item.assignments[person] ?? 0) > 0)
            .toList();

    // Calculate person's base amounts from CalculationUtils
    final personAmounts = CalculationUtils.calculatePersonAmounts(
      person: person,
      participants: data.participants,
      personShares: data.personShares,
      items: data.items,
      subtotal: data.subtotal,
      tax: data.tax,
      tipAmount: data.tipAmount,
      birthdayPerson: data.birthdayPerson,
    );

    // Calculate total share
    final double totalShare = personAmounts['total'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Person header with total
          _buildPersonHeader(context, isBirthdayPerson, totalShare),

          // Items list (if any)
          if (personItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),

            ...personItems.map((item) => _buildItemRow(context, item, person)),

            if (!isBirthdayPerson) // Only add divider if not birthday person
              const Divider(height: 16, indent: 16, endIndent: 16),
          ],

          // Tax and tip details - only for non-birthday people
          if (!isBirthdayPerson)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  if ((personAmounts['tax'] ?? 0) > 0)
                    _buildAmountRow(
                      'Tax',
                      (personAmounts['tax'] ?? 0),
                      isTotal: false,
                    ),

                  // Only show tip if amount > 0
                  if ((personAmounts['tip'] ?? 0) > 0)
                    _buildAmountRow(
                      'Tip',
                      (personAmounts['tip'] ?? 0),
                      isTotal: false,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonHeader(
    BuildContext context,
    bool isBirthdayPerson,
    double totalShare,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isBirthdayPerson
                ? Colors.pink.shade50
                : person.color.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: person.color,
            radius: 20,
            child: Text(
              person.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isBirthdayPerson)
                  Row(
                    children: [
                      Icon(Icons.cake, size: 14, color: Colors.pink.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Happy Birthday!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.pink.shade400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isBirthdayPerson
                      ? Colors.pink.shade100
                      : person.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '\$${totalShare.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    isBirthdayPerson
                        ? Colors.pink.shade700
                        : ColorUtils.getDarkenedColor(person.color, 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, BillItem item, Person person) {
    final percentage = item.assignments[person] ?? 0;

    // Calculate amount from the item price
    final amount = item.price * (percentage / 100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ),
          if (percentage < 100)
            Text(
              '${percentage.toStringAsFixed(0)}% × ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 15 : 14,
              color: color,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 15 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
