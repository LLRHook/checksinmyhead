import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/item_assignment_screen.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/utils/bill_calculations.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';

class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final RecentBillModel? bill; // Bill parameter for reuse functionality

  const BottomBar({Key? key, required this.onShareTap, this.bill})
    : super(key: key);

  // Directly reuse a bill without overlay
  void _reuseBill(BuildContext context) {
    if (bill == null) {
      // Show error if bill is not provided
      _showSnackBar(
        context,
        'Cannot reuse bill: No bill data available',
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      // 1. Create participants from saved data
      final participants =
          bill!.participantNames.map((name) {
            // Get a color for this person
            return Person(name: name, color: _getColorForParticipant(name));
          }).toList();

      // 2. Create BillItem objects from the saved items
      final billCalculations = BillCalculations(bill!);
      final items = billCalculations.generateBillItems();

      // 3. Navigate to the item assignment screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => ItemAssignmentScreen(
                participants: participants,
                items: items,
                subtotal: bill!.subtotal,
                tax: bill!.tax,
                tipAmount: bill!.tipAmount,
                total: bill!.total,
                tipPercentage: bill!.tipPercentage,
                alcoholTipPercentage: 0.0,
                useDifferentAlcoholTip: false,
                isCustomTipAmount: false,
              ),
        ),
      );
    } catch (e) {
      // Show error snackbar
      _showSnackBar(
        context,
        'Failed to reuse bill: ${e.toString()}',
        isError: true,
      );
    }
  }

  // Helper to show a snackbar
  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    // Theme-aware colors for the snackbar
    final snackBarBgColor =
        isError
            ? (brightness == Brightness.dark
                ? const Color(0xFF3A0D0D) // Dark red for dark mode
                : colorScheme.error)
            : (brightness == Brightness.dark
                ? const Color(0xFF2D2D2D) // Dark gray for dark mode
                : null); // Default for light mode

    final snackBarTextColor =
        isError || brightness == Brightness.dark
            ? Colors.white
            : null; // Default for light mode

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: snackBarTextColor)),
        backgroundColor: snackBarBgColor,
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width * 0.9,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Helper to get a color for a participant
  Color _getColorForParticipant(String name) {
    // Get a consistent color based on name
    final colors = ColorUtils.getParticipantColors();
    final index = name.hashCode % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.03);

    // Outline button colors
    final outlineColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.8)
            : colorScheme.primary;

    // Button text color - for dark mode, use darker text on bright backgrounds for contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(
              0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Share button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareTap,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: outlineColor,
                  side: BorderSide(color: outlineColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
