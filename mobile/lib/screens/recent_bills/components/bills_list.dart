import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'recent_bill_card.dart';

/// BillsList
///
/// A widget that displays a scrollable list of recent bills using a ListView.
///
/// This component renders each bill in the provided list as a RecentBillCard,
/// handling the layout, spacing, and scrolling behavior automatically. It also
/// passes through the deletion callback to each card to maintain data consistency
/// when bills are removed.
///
/// Features:
/// - Efficient rendering using ListView.builder for performance with large lists
/// - Consistent padding around all list items
/// - Propagates deletion events back to the parent widget
///
/// This component is designed to be used within the recent bills screen and
/// requires a list of RecentBillModel objects to display.
class BillsList extends StatelessWidget {
  /// The list of bill models to display
  final List<RecentBillModel> bills;

  /// Callback function triggered when any bill is deleted
  /// This allows the parent widget to refresh data or update state
  final VoidCallback onBillDeleted;

  const BillsList({
    super.key,
    required this.bills,
    required this.onBillDeleted,
  });

  @override
  Widget build(BuildContext context) {
    // Use ListView.builder for efficient rendering of potentially large lists
    // Only visible items and a small buffer are built at any given time
    return ListView.builder(
      padding: const EdgeInsets.all(16), // Consistent padding around all cards
      itemCount: bills.length,
      itemBuilder: (context, index) {
        // Create a card for each bill in the list
        return RecentBillCard(
          bill: bills[index],
          onDeleted: onBillDeleted, // Pass the deletion callback to each card
        );
      },
    );
  }
}
