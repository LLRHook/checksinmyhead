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

import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_name_sheet.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/enhanced_share_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';

/// BottomBar - Fixed navigation bar at bottom of bill screens
///
/// Displays "Share" and "Done" buttons for completing bill actions.
/// Uses a consolidated BillSummaryData object for all bill information.
class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final Function onDoneTap;
  final BillSummaryData data;
  final bool lazyMode;
  final AppTab? tab;

  const BottomBar({
    super.key,
    required this.onShareTap,
    required this.onDoneTap,
    required this.data,
    this.lazyMode = false,
    this.tab,
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
        child:
            lazyMode
                ? FilledButton.icon(
                  onPressed: () {
                    onDoneTap();
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Create Link'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: buttonTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                : Row(
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
  static bool _isSaving = false;

  static Future<SaveReceiptResult?> handleDone(
    BuildContext context, {
    required BillSummaryData data,
    bool lazyMode = false,
    AppTab? tab,
    String? operationHandle,
    RecentBillsManager? manager,
    Future<String> Function()? confirmName,
    Future<void> Function(SaveReceiptResult, BillSummaryData)? presentSaved,
    VoidCallback? navigateHome,
  }) async {
    if (_isSaving) return null;
    _isSaving = true;
    DialogRoute<void>? loading;
    final navigator = Navigator.of(context);
    void closeLoading() {
      if (loading?.isActive == true) navigator.removeRoute(loading!);
    }

    try {
      // Pure preflight exposes invalid raw assignments and labels before naming.
      // The manager alone owns persistence, publication and recovery.
      try {
        ApiService().buildBillRequest(
          billName: data.billName,
          participants: lazyMode ? const [] : data.participants,
          personShares: lazyMode ? const {} : data.personShares,
          items: data.items,
          subtotal: data.subtotal,
          tax: data.tax,
          tipAmount: data.tipAmount,
          tipPercentage: data.tipPercentage,
          total: data.total,
          paymentMethods: data.paymentMethods,
          currencyCode: data.currencyCode,
          lazyMode: lazyMode,
        );
      } on BillValidationException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
        return null;
      }
      final name =
          await (confirmName?.call() ??
              BillNameSheet.show(context: context, initialName: data.billName));
      if (name.isEmpty || !context.mounted) return null;
      loading = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      navigator.push(loading);
      var payments = data.paymentMethods;
      try {
        final prefs = PreferencesService();
        final selected = await prefs.getSelectedPaymentMethods();
        final identifiers = await prefs.getAllPaymentIdentifiers();
        payments = [
          for (final method in selected)
            {'name': method, 'identifier': identifiers[method] ?? ''},
        ];
      } catch (_) {
        /* Preserve the confirmed draft's payment snapshot. */
      }
      final confirmed = data.copyWith(billName: name, paymentMethods: payments);
      SaveReceiptResult result;
      try {
        result = await (manager ?? RecentBillsManager()).saveReceipt(
          operationHandle:
              operationHandle ?? RecentBillsManager.newOperationHandle(),
          receipt: confirmed,
          lazyMode: lazyMode,
          displayCurrency: lazyMode ? null : tab?.displayCurrency,
          intendedTabId: lazyMode ? null : tab?.id,
        );
      } catch (_) {
        closeLoading();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save on this device. Review the receipt and retry.',
              ),
            ),
          );
        }
        return null;
      }
      closeLoading();
      // Everything below consumes a committed result. Presentation failures must
      // not be caught as persistence failures or trigger a second local save.
      try {
        if (presentSaved != null) {
          await presentSaved(result, confirmed);
        } else if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
          await EnhancedShareSheet.show(
            context: context,
            shareUrl: result.shareUrl,
            data: confirmed,
          );
        }
      } catch (_) {
        /* The saved receipt remains in history. */
      }
      try {
        if (navigateHome != null) {
          navigateHome();
        } else if (navigator.mounted) {
          navigator.popUntil((route) => route.isFirst);
        }
      } catch (_) {
        /* Navigation cannot undo a committed receipt. */
      }
      return result;
    } finally {
      closeLoading();
      _isSaving = false;
    }
  }
}
