// Billington: Privacy-first receipt spliting
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

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_name_sheet.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/enhanced_share_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

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
  static final _billsManager = RecentBillsManager();
  static final _apiService = ApiService();
  static final _prefsService = PreferencesService();
  static bool _isSaving = false;

  /// Saves the bill locally and uploads to backend
  static Future<void> handleDone(
    BuildContext context, {
    required BillSummaryData data,
  }) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      // Capture ALL context-dependent references FIRST (before any async)
      final navigator = Navigator.of(context);

      // Get bill name
      final billName = await BillNameSheet.show(
        context: context,
        initialName: data.billName,
      );

      if (billName.isEmpty) {
        return; // User cancelled
      }

      // Check context.mounted before using context
      if (!context.mounted) {
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => const Center(child: CircularProgressIndicator()),
      );

      // Load payment methods from preferences
      final selectedMethods = await _prefsService.getSelectedPaymentMethods();
      final identifiers = await _prefsService.getAllPaymentIdentifiers();

      // Convert to the format expected by the API
      final paymentMethods =
          selectedMethods.map((method) {
            return {'name': method, 'identifier': identifiers[method] ?? ''};
          }).toList();

      // Create updated data with bill name and payment methods
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
        billName: billName,
        paymentMethods: paymentMethods,
      );

      // Save locally first (always works even if backend fails)
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

      // Try to upload to backend
      String? shareUrl;
      var logger = Logger();
      try {
        // Use payment methods from settings, or provide defaults
        final apiPaymentMethods =
            paymentMethods.isNotEmpty
                ? paymentMethods
                : [
                  {'name': 'Venmo', 'identifier': '@username'},
                ];

        final response = await _apiService.uploadBill(
          billName: billName,
          participants: updatedData.participants,
          personShares: updatedData.personShares,
          items: updatedData.items,
          subtotal: updatedData.subtotal,
          tax: updatedData.tax,
          tipAmount: updatedData.tipAmount,
          tipPercentage: updatedData.tipPercentage,
          total: updatedData.total,
          paymentMethods: apiPaymentMethods,
        );

        if (response != null) {
          shareUrl = response.shareUrl;
          logger.d('Bill uploaded successfully: $shareUrl');

          // Persist the share URL to the most recently saved bill
          final mostRecent = await DatabaseProvider.db.getMostRecentBill();
          if (mostRecent != null) {
            await _billsManager.updateBillShareUrl(mostRecent.id, shareUrl);
          }
        }
      } catch (e) {
        logger.d('Failed to upload to backend: $e');
        // Continue anyway - local save succeeded
      }

      // Close loading dialog
      if (navigator.mounted) {
        navigator.pop(); // Close loading dialog
      }

      if (!navigator.mounted) {
        return;
      }

      HapticFeedback.mediumImpact();

      // Show EnhancedShareSheet instead of snackbar
      if (context.mounted) {
        await EnhancedShareSheet.show(
          context: context,
          shareUrl: shareUrl,
          data: updatedData,
        );
      }

      // Return to home
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
    } finally {
      _isSaving = false;
    }
  }
}
