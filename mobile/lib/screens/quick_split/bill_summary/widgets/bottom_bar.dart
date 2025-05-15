// Checkmate: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_name_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BottomBar - Fixed navigation bar at bottom of bill screens
///
/// Displays "Share" and "Done" buttons for completing bill actions.
/// Uses a consolidated BillSummaryData object for all bill information.
class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final Function onDoneTap;
  final BillSummaryData data;

  const BottomBar({
    super.key,
    required this.onShareTap,
    required this.onDoneTap,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.05);

    // In dark mode, use dark text on bright buttons for better contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white;

    final outlineButtonColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: 0.8)
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

/// Utility class to handle the "Done" button actions
///
/// Provides a method to save bill data, show confirmation,
/// and navigate back to the starting screen.
class DoneButtonHandler {
  /// Bills manager instance
  static final _billsManager = RecentBillsManager();

  /// Saves the bill and handles UI feedback
  ///
  /// Prompts for a bill name, saves to storage, shows confirmation message,
  /// provides haptic feedback, and navigates back to first screen.
  /// Uses a BillSummaryData object to simplify parameter passing.
  static Future<void> handleDone(
    BuildContext context, {
    required BillSummaryData data,
  }) async {
    // Bill naming dialog is shown here with a premium bottom sheet
    final billName = await BillNameSheet.show(
      context: context,
      initialName: data.billName, // Use any previously set name
    );

    // If the user dismissed the sheet without entering a name, just return to the summary screen
    if (billName.isEmpty) {
      return; // Don't save the bill, just return to the summary screen
    }

    // Capture theme info before async operation
    final brightness = Theme.of(context).brightness;
    final snackBarBgColor =
        brightness == Brightness.dark ? const Color(0xFF2D2D2D) : null;

    final snackBarTextColor =
        brightness == Brightness.dark ? Colors.white : null;

    // Store a navigator reference to avoid context usage after async gap
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Create a new BillSummaryData with the updated bill name
    final updatedData = BillSummaryData(
      participants: data.participants,
      personShares: data.personShares,
      items: data.items,
      subtotal: data.subtotal,
      tax: data.tax,
      tipAmount: data.tipAmount,
      total: data.total,
      birthdayPerson: data.birthdayPerson,
      tipPercentage: data.tipPercentage,
      isCustomTipAmount: data.isCustomTipAmount,
      billName: billName, // Use the name from dialog
    );

    // Save bill data using the consolidated BillSummaryData object
    await _billsManager.saveBill(
      participants: updatedData.participants,
      personShares: updatedData.personShares,
      items: updatedData.items,
      subtotal: updatedData.subtotal,
      tax: updatedData.tax,
      tipAmount: updatedData.tipAmount,
      total: updatedData.total,
      birthdayPerson: updatedData.birthdayPerson,
      tipPercentage: updatedData.tipPercentage,
      isCustomTipAmount: updatedData.isCustomTipAmount,
      billName: updatedData.billName,
    );

    // Check if widget is still mounted before proceeding
    if (!navigator.mounted) return;

    // Show success message using the stored scaffoldMessenger
    scaffoldMessenger.showSnackBar(
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

    HapticFeedback.mediumImpact();

    // Return to home screen using the stored navigator reference
    navigator.popUntil((route) => route.isFirst);
  }
}
