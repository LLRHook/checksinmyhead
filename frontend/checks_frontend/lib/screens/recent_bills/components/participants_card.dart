import 'package:checks_frontend/screens/recent_bills/billDetails/utils/bill_calculations.dart';
import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

class ParticipantsCard extends StatefulWidget {
  final RecentBillModel bill;
  final BillCalculations calculations;

  const ParticipantsCard({
    Key? key,
    required this.bill,
    required this.calculations,
  }) : super(key: key);

  @override
  State<ParticipantsCard> createState() => _ParticipantsCardState();
}

class _ParticipantsCardState extends State<ParticipantsCard> {
  // Map to track expansion state for each participant
  final Map<String, bool> _expansionState = {};

  @override
  void initState() {
    super.initState();
    // Set initial expansion state (first participant expanded)
    if (widget.bill.participantNames.isNotEmpty) {
      _expansionState[widget.bill.participantNames[0]] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get totals for each person
    final personTotals = widget.calculations.calculatePersonTotals();

    // Check if we have real assignments
    final hasRealAssignments = widget.calculations.hasRealAssignments();
    final equalShare = widget.calculations.calculateEqualShare();

    return Card(
      elevation: 1,
      surfaceTintColor: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Participants',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.bill.participantCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Participants list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.bill.participantNames.length,
            itemBuilder: (context, index) {
              final name = widget.bill.participantNames[index];
              // Check if this participant's tile is expanded
              final isExpanded = _expansionState[name] ?? false;

              // Get amounts for this person
              final totalAmount =
                  hasRealAssignments ? (personTotals[name] ?? 0.0) : equalShare;

              final taxAndTipAmount =
                  widget.calculations.calculatePersonTaxAndTip()[name] ?? 0.0;

              // Get items this person is paying for
              List<Map<String, dynamic>> personItems = [];
              if (widget.bill.items != null) {
                for (var item in widget.bill.items!) {
                  final itemName = item['name'] as String? ?? 'Unknown Item';
                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                  final assignments =
                      item['assignments'] as Map<String, dynamic>?;

                  if (assignments != null && assignments.containsKey(name)) {
                    final percentage = assignments[name] as num;
                    if (percentage > 0) {
                      final itemAmount = price * percentage / 100;
                      // Only flag as shared if percentage < 100
                      final isShared = percentage < 100;
                      personItems.add({
                        'name': itemName,
                        'price': itemAmount,
                        'percentage': percentage,
                        'isShared': isShared,
                      });
                    }
                  }
                }
              }

              // Sort items by price (highest first)
              personItems.sort(
                (a, b) =>
                    (b['price'] as double).compareTo(a['price'] as double),
              );

              // Create a widget for this participant
              return Column(
                children: [
                  // Add a divider before each participant except the first one
                  if (index > 0)
                    Divider(
                      color: Colors.grey.shade200,
                      height: 1,
                      thickness: 1,
                    ),

                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      backgroundColor: Colors.white,
                      collapsedBackgroundColor: Colors.white,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.only(
                        left: 56,
                        right: 16,
                        bottom: 16,
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      maintainState: true,
                      initiallyExpanded:
                          index == 0, // First one expanded by default
                      onExpansionChanged: (expanded) {
                        // Update the expansion state for this participant
                        setState(() {
                          _expansionState[name] = expanded;
                        });
                      },
                      // Leading avatar
                      leading: CircleAvatar(
                        backgroundColor: _getPersonColor(index, colorScheme),
                        radius: 20,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Title is person's name
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),

                      // Subtitle is a preview of what they're paying for
                      subtitle:
                          personItems.isNotEmpty
                              ? Text(
                                '${personItems.length} item(s)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              )
                              : null,

                      // Trailing is the amount
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(
                                0.7,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              CurrencyFormatter.formatCurrency(totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          if (personItems.isNotEmpty) const SizedBox(height: 4),
                          if (personItems.isNotEmpty)
                            Text(
                              // Use the tracked expansion state to change the text
                              isExpanded ? 'Close details' : 'View details',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),

                      // Children are the breakdown of items and tax/tip
                      children: [
                        if (personItems.isNotEmpty) ...[
                          // Items header
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                          // Item rows
                          ...personItems.map(
                            (item) => _buildItemRow(
                              context,
                              item['name'] as String,
                              item['price'] as double,
                              item['percentage'] as num,
                              colorScheme,
                            ),
                          ),
                        ],

                        // Standard Tax & Tip section (if applicable)
                        if (taxAndTipAmount > 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Row(
                              children: [
                                // Tax & Tip label
                                Text(
                                  'Tax & Tip',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),

                                // Spacer to push the amount to the right
                                const Spacer(),

                                // Amount - now using the same text style as regular text
                                Text(
                                  CurrencyFormatter.formatCurrency(
                                    taxAndTipAmount,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    String name,
    double amount,
    num percentage,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 14),
          // Bullet point
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Item name
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ),

          // Amount and percentage
          Row(
            children: [
              // Amount
              Text(
                CurrencyFormatter.formatCurrency(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),

              // Only show percentage badge if it's a partial amount
              if (percentage < 100) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Get a color for the person's avatar based on their index
  Color _getPersonColor(int index, ColorScheme colorScheme) {
    final colors = [
      colorScheme.primary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.deepPurple,
      Colors.pink,
      Colors.brown,
    ];

    return colors[index % colors.length];
  }
}
