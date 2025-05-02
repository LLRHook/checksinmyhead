import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final Function onDoneTap;
  final List<Person> participants;
  final Map<Person, double> personShares;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final Person? birthdayPerson;

  const BottomBar({
    Key? key,
    required this.onShareTap,
    required this.onDoneTap,
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
  }) : super(key: key);

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
            : Colors.black.withOpacity(0.05);

    final labelColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.7)
            : Colors.grey;

    final valueColor = colorScheme.onSurface;

    // Button text color - for dark mode, use darker text on bright backgrounds for contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(
              0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    // Outline button colors
    final outlineButtonColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.8)
            : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareTap,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: outlineButtonColor,
                  side: BorderSide(color: outlineButtonColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  // Save bill and handle done
                  onDoneTap();
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: buttonTextColor,
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

// Helper class for external use (if needed)
class DoneButtonHandler {
  static Future<void> handleDone(
    BuildContext context, {
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    Person? birthdayPerson,
    double tipPercentage = 0, // New parameter
    bool isCustomTipAmount = false, // New parameter
  }) async {
    // Get theme info for snackbar
    final brightness = Theme.of(context).brightness;
    final snackBarBgColor =
        brightness == Brightness.dark
            ? const Color(0xFF2D2D2D) // Darker background for dark mode
            : null; // Use default for light mode

    final snackBarTextColor =
        brightness == Brightness.dark
            ? Colors.white
            : null; // Use default for light mode

    // Save the bill to the database
    await RecentBillsManager.saveBill(
      participants: participants,
      personShares: personShares,
      items: items,
      subtotal: subtotal,
      tax: tax,
      tipAmount: tipAmount,
      total: total,
      birthdayPerson: birthdayPerson,
      tipPercentage: tipPercentage, // Pass the tip percentage
      isCustomTipAmount:
          isCustomTipAmount, // Pass whether it's a custom tip amount
    );

    // Show success message with theme-aware colors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bill saved successfully',
          style: TextStyle(color: snackBarTextColor),
        ),
        backgroundColor: snackBarBgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Navigate to first screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
