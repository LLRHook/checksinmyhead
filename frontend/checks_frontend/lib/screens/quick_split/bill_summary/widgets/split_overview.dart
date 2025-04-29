import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';
import '../utils/color_utils.dart';
import '/models/person.dart';

class SplitOverview extends StatelessWidget {
  final BillSummaryData data;

  const SplitOverview({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate distribution percentages
    List<Map<String, dynamic>> distribution = [];
    double totalAmount = data.total > 0 ? data.total : 1;

    for (var person in data.participants) {
      final share = data.personShares[person] ?? 0;
      final percentage = (share / totalAmount) * 100;

      if (percentage > 0.5) {
        distribution.add({'person': person, 'percentage': percentage});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Split Distribution',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // Distribution bar
        Container(
          height: 24,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              for (var dist in distribution)
                Expanded(
                  flex: dist['percentage'].round(),
                  child: Container(
                    color: (dist['person'] as Person).color,
                    child:
                        dist['percentage'] > 10
                            ? Center(
                              child: Text(
                                '${dist['percentage'].toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            : const SizedBox(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Legend
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              data.participants.map((person) {
                final share = data.personShares[person] ?? 0;
                final percentage = (share / totalAmount) * 100;

                if (percentage < 0.5) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: person.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: person.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: person.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.getDarkenedColor(person.color, 0.3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\$${share.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.getDarkenedColor(person.color, 0.3),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}
