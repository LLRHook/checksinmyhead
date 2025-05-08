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

import 'package:checks_frontend/screens/quick_split/item_assignment/item_assignment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';

// Models
import 'models/bill_data.dart';

// Widgets
import 'widgets/participant_avatars.dart';
import 'widgets/bill_total_section.dart';
import 'widgets/tip_options_section.dart';
import 'widgets/items_section.dart';
import 'widgets/bill_summary_section.dart';
import 'widgets/continue_button.dart';

/// BillEntryScreen - Main interface for entering bill details
///
/// This screen allows users to:
/// - Enter bill subtotal and tax
/// - Configure tip amount (percentage or custom)
/// - Add itemized expenses
/// - Review bill summary before proceeding
///
/// The screen handles validation to ensure that:
/// - A subtotal is entered
/// - At least one item is added
/// - The items' total matches the entered subtotal
///
/// Inputs:
///   - List of participants from the previous screen
///
/// Side effects:
///   - Creates and manages a BillData instance
///   - Navigates to ItemAssignmentScreen when valid data is entered
class BillEntryScreen extends StatefulWidget {
  final List<Person> participants;

  const BillEntryScreen({super.key, required this.participants});

  @override
  State<BillEntryScreen> createState() => _BillEntryScreenState();
}

class _BillEntryScreenState extends State<BillEntryScreen> {
  late final BillData _billData;

  @override
  void initState() {
    super.initState();
    _billData = BillData();
  }

  @override
  void dispose() {
    _billData.dispose();
    super.dispose();
  }

  /// Validates bill data and proceeds to item assignment screen
  ///
  /// Checks that:
  /// - Subtotal is greater than zero
  /// - At least one item has been added
  /// - Total of all items matches the entered subtotal (within rounding tolerance)
  void _continueToItemAssignment() {
    if (_billData.subtotal <= 0) {
      _showSnackBar('Please enter a subtotal amount');
      return;
    }

    // Check if items have been added
    if (_billData.items.isEmpty) {
      _showValidationError('Please add at least one item');
      return;
    }

    // Check if items total matches the subtotal (allowing for a small rounding error)
    final difference = (_billData.subtotal - _billData.itemsTotal).abs();
    if (difference > 0.01) {
      _showValidationError('Missing some items? Your totals don\'t match yet.');
      return;
    }

    // Provide haptic feedback for continuing
    HapticFeedback.mediumImpact();

    // All good, navigate to the next screen
    _navigateToItemAssignment();
  }

  /// Shows a detailed validation error in a bottom sheet
  ///
  /// Displays an error message with an icon and a dismissible button,
  /// providing clear feedback about validation issues.
  void _showValidationError(String message) {
    // Provide haptic feedback for error
    HapticFeedback.vibrate();

    // Show modern validation error banner
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon in a colored container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Items Don\'t Add Up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'OK, GOT IT',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navigates to the item assignment screen with bill data
  ///
  /// Passes all necessary bill information to the next screen for
  /// assigning items to participants.
  void _navigateToItemAssignment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ItemAssignmentScreen(
              participants: widget.participants,
              items: _billData.items,
              subtotal: _billData.subtotal,
              tax: _billData.tax,
              tipAmount: _billData.tipAmount,
              total: _billData.total,
              tipPercentage: _billData.tipPercentage,
              isCustomTipAmount: _billData.useCustomTipAmount,
            ),
      ),
    );
  }

  /// Shows a floating snackbar with an info icon
  ///
  /// Used for lightweight notifications that don't require
  /// user intervention to dismiss.
  void _showSnackBar(String message) {
    // Provide haptic feedback for error
    HapticFeedback.vibrate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width * 0.9,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _billData,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enter Bill Details'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: GestureDetector(
          // Dismiss keyboard when tapping outside input fields
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Horizontal scrollable list of participant avatars
              ParticipantAvatars(participants: widget.participants),

              const SizedBox(height: 20),

              // Subtotal and tax input fields
              const BillTotalSection(),

              const SizedBox(height: 20),

              // Tip configuration (percentage or custom amount)
              const TipOptionsSection(),

              const SizedBox(height: 20),

              // Itemized bill entry with progress tracking
              ItemsSection(showSnackBar: _showSnackBar),

              const SizedBox(height: 20),

              // Overview of bill totals
              const BillSummarySection(),

              const SizedBox(height: 24),

              // Adaptive continue button with validation
              ContinueButton(onPressed: _continueToItemAssignment),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
