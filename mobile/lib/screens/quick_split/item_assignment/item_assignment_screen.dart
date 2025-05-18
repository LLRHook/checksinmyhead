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

import 'package:checks_frontend/screens/quick_split/item_assignment/dialogs/custom_split_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'tutorial/tutorial_manager.dart';

// Widgets
import 'widgets/unassigned_amount_banner.dart';
import 'widgets/assignment_app_bar.dart';
import 'widgets/assignment_bottom_bar.dart';
import 'widgets/item_card.dart'; // Import the enhanced version

// Bill summary screen
import 'package:checks_frontend/screens/quick_split/bill_summary/bill_summary_screen.dart';

// Provider and utils
import 'providers/assignment_provider.dart';
import 'utils/assignment_utils.dart';
import 'models/assignment_result.dart';

// Screen that allows users to assign bill items to participants
// Shows a list of items with options to split them among people
class ItemAssignmentScreen extends StatefulWidget {
  // List of people sharing the bill
  final List<Person> participants;
  // List of items on the bill to be assigned
  final List<BillItem> items;
  // Bill amounts
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final double tipPercentage;
  // Whether tip was entered as a custom amount rather than percentage
  final bool isCustomTipAmount;
  final Person? initialBirthdayPerson;

  const ItemAssignmentScreen({
    super.key,
    required this.participants,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    required this.tipPercentage,
    required this.isCustomTipAmount,
    this.initialBirthdayPerson,
  });

  @override
  State<ItemAssignmentScreen> createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for UI elements
  late AnimationController _animationController;

  // Tutorial manager
  late TutorialManager _tutorialManager;
  bool _tutorialManagerInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    // Initialize tutorial manager asynchronously
    _initTutorialManager();
  }

  // Initializes the tutorial manager and triggers UI update when ready
  Future<void> _initTutorialManager() async {
    _tutorialManager = await TutorialManager.create();
    if (mounted) {
      setState(() {
        _tutorialManagerInitialized = true;
      });

      _tutorialManager.initializeWithDelay(() => context, mounted);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();

    // Dispose tutorial manager if initialized
    if (_tutorialManagerInitialized) {
      _tutorialManager.dispose();
    }

    super.dispose();
  }

  // Validates assignment completeness and navigates to summary or shows error
  void _checkAssignmentComplete(
    BuildContext context,
    AssignmentProvider provider,
  ) {
    // Get theme info
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for dialog
    final dialogBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final errorIconBgColor = colorScheme.error.withValues(
      alpha: brightness == Brightness.dark ? 0.2 : 0.1,
    );

    // Check if everything is assigned
    if (provider.unassignedAmount > 0.01) {
      // Provide haptic feedback for error
      HapticFeedback.vibrate();

      // Show modern validation error banner
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isDismissible: true,
        backgroundColor: dialogBgColor,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: errorIconBgColor,
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
                  'Items Not Fully Assigned',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "There's still \$${provider.unassignedAmount.toStringAsFixed(2)} unassigned. Please assign all items before continuing.",
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
      return;
    }

    // Navigate to summary screen with animation
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => BillSummaryScreen(
              participants: widget.participants,
              personShares: provider.personFinalShares,
              items: widget.items,
              subtotal: widget.subtotal,
              tax: widget.tax,
              tipAmount: widget.tipAmount,
              total: widget.total,
              birthdayPerson: provider.birthdayPerson,
              tipPercentage: widget.tipPercentage,
              isCustomTipAmount: widget.isCustomTipAmount,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Convenience method for the continue button
  void _continueToSummary(AssignmentProvider provider) {
    // Provide haptic feedback for continue button tap
    HapticFeedback.mediumImpact();
    _checkAssignmentComplete(context, provider);
  }

  // Shows dialog for custom splitting of an item
  void _showCustomSplitDialog(
    BillItem item,
    List<Person> preselectedPeople,
    AssignmentProvider provider,
  ) {
    showCustomSplitDialog(
      context: context,
      item: item,
      participants: widget.participants,
      onAssign: provider.assignItem,
      preselectedPeople: preselectedPeople,
      birthdayPerson: provider.birthdayPerson,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => AssignmentProvider(
            participants: widget.participants,
            items: widget.items,
            subtotal: widget.subtotal,
            tax: widget.tax,
            tipAmount: widget.tipAmount,
            total: widget.total,
            tipPercentage: widget.tipPercentage,
            isCustomTipAmount: widget.isCustomTipAmount,
            initialBirthdayPerson: widget.initialBirthdayPerson,
          ),
      child: Consumer<AssignmentProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AssignmentAppBar(
              onBackPressed: () {
                // Return updated item assignments and birthday person when navigating back
                Navigator.pop(
                  context,
                  AssignmentResult(
                    items: provider.items,
                    birthdayPerson: provider.birthdayPerson,
                  ),
                );
              },
              onHelpPressed:
                  _tutorialManagerInitialized
                      ? () => _tutorialManager.showTutorial(context)
                      : null,
              showHelpButton: _tutorialManagerInitialized,
            ),
            body: Column(
              children: [
                // Unassigned amount banner at top when needed
                if (provider.unassignedAmount > 0.01)
                  UnassignedAmountBanner(
                    unassignedAmount: provider.unassignedAmount,
                    onSplitEvenly: provider.splitUnassignedAmountEvenly,
                  ),

                // Bill information panel
                _buildBillInfoPanel(provider),

                // Items list
                Expanded(child: _buildItemsListView(provider)),

                // Bottom control bar with continue button
                AssignmentBottomBar(
                  totalBill: widget.total,
                  onContinueTap: () => _continueToSummary(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Bill information panel showing assignment progress
  Widget _buildBillInfoPanel(AssignmentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Calculate how much of the bill has been assigned
    final assignedAmount = widget.subtotal - provider.unassignedAmount;
    final assignedPercentage =
        widget.subtotal > 0
            ? (assignedAmount / widget.subtotal * 100).clamp(0.0, 100.0)
            : 0.0;

    // Theme-aware colors - using transparent background in dark mode for seamless look
    final panelBgColor =
        brightness == Brightness.dark ? Colors.transparent : Colors.white;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors
                .transparent // No shadow in dark mode for seamless look
            : Colors.black.withValues(alpha: .05);

    final labelColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .7)
            : Colors.grey.shade600;

    final valueColor = colorScheme.onSurface;

    final successColor =
        brightness == Brightness.dark
            ? Colors
                .green
                .shade400 // Lighter green for dark mode
            : Colors.green.shade700;

    final trackBgColor =
        brightness == Brightness.dark
            ? Colors.grey.shade900.withValues(alpha: .4)
            : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: panelBgColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with bill info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bill amount column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${widget.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                  ),
                ],
              ),

              // Assigned amount column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Assigned',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${assignedAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          assignedPercentage >= 100
                              ? successColor
                              : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          Stack(
            children: [
              // Background track
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: trackBgColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Progress indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: 6,
                width:
                    MediaQuery.of(context).size.width *
                    (assignedPercentage / 100) *
                    ((MediaQuery.of(context).size.width - 40) /
                        MediaQuery.of(context).size.width),
                decoration: BoxDecoration(
                  color:
                      assignedPercentage >= 100
                          ? successColor
                          : colorScheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),

          // Percentage text
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${assignedPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      assignedPercentage >= 100
                          ? successColor
                          : colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the scrollable list of bill items
  Widget _buildItemsListView(AssignmentProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        // Calculate percentage of item assigned
        final assignedPercentage = item.assignments.values.fold(
          0.0,
          (sum, value) => sum + value,
        );

        // Get all people assigned to this item
        final assignedPeople = AssignmentUtils.getAssignedPeopleForItem(item);

        return ItemCard(
          key: ValueKey('item-${item.name}'),
          item: item,
          assignedPercentage: assignedPercentage,
          participants: widget.participants,
          assignedPeople: assignedPeople,
          universalItemIcon: provider.universalItemIcon,
          onAssign: provider.assignItem,
          onSplitEvenly: provider.splitItemEvenly,
          onShowCustomSplit:
              (item, preselectedPeople) =>
                  _showCustomSplitDialog(item, preselectedPeople, provider),
          birthdayPerson: provider.birthdayPerson,
          onBirthdayToggle: provider.toggleBirthdayPerson,
          getPersonBillPercentage: provider.getPersonBillPercentage,
        );
      },
    );
  }
}
