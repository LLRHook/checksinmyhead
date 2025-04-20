import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class BillSummaryScreen extends StatelessWidget {
  final List<Person> participants;
  final Map<Person, double> personShares;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final Person? birthdayPerson;

  const BillSummaryScreen({
    super.key,
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Summary'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bill overview
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bill Total: \$${total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tax & tip split proportionally based on orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('\$${subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tax:'),
                            Text('\$${tax.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tip:'),
                            Text('\$${tipAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Individual Shares',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                ...participants.map((person) {
                  final amount = personShares[person] ?? 0;
                  final isBirthdayPerson = birthdayPerson == person;
                  final personSubtotal = _getPersonSubtotal(person);
                  final personTaxAndTip = amount - personSubtotal;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color:
                        isBirthdayPerson ? Colors.green.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            isBirthdayPerson
                                ? Colors.green.shade300
                                : person.color.withOpacity(0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: person.color,
                                radius: 16,
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
                                child: Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isBirthdayPerson
                                          ? Colors.green.shade700
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          if (isBirthdayPerson) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.cake,
                                  size: 16,
                                  color: Colors.pink,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Birthday person! Share split among others.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Items:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items
                                .where((item) {
                                  return (item.assignments[person] ?? 0) > 0;
                                })
                                .map((item) {
                                  final percentage =
                                      item.assignments[person] ?? 0;
                                  final itemAmount =
                                      item.price * (percentage / 100);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (percentage != 100)
                                          Text(
                                            '${percentage.toStringAsFixed(0)}% × ',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        Text(
                                          '\$${itemAmount.toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Tooltip(
                                  message:
                                      'Your share: '
                                      '\$${(personTaxAndTip * (tax / (tax + tipAmount))).toStringAsFixed(2)} tax + '
                                      '\$${(personTaxAndTip * (tipAmount / (tax + tipAmount))).toStringAsFixed(2)} tip',
                                  triggerMode: TooltipTriggerMode.tap,
                                  showDuration: Duration(seconds: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('+ Tax & Tip'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '\$${personTaxAndTip.toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _shareBillSummary(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _saveBill(context);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getPersonSubtotal(Person person) {
    double subtotal = 0.0;
    for (var item in items) {
      subtotal += item.amountForPerson(person);
    }
    return subtotal;
  }

  void _shareBillSummary(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sharing functionality will be implemented in a future update',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveBill(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
