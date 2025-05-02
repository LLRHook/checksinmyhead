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

// Dialogs
import 'dialogs/unassigned_warning_dialog.dart';

// Bill summary screen
import 'package:checks_frontend/screens/quick_split/bill_summary/bill_summary_screen.dart';

// Provider and utils
import 'providers/assignment_provider.dart';
import 'utils/assignment_utils.dart';

class ItemAssignmentScreen extends StatefulWidget {
  final List<Person> participants;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final double tipPercentage;
  final double alcoholTipPercentage;
  final bool useDifferentAlcoholTip;
  final bool isCustomTipAmount;

  const ItemAssignmentScreen({
    super.key,
    required this.participants,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    required this.tipPercentage,
    required this.alcoholTipPercentage,
    required this.useDifferentAlcoholTip,
    required this.isCustomTipAmount,
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

  Future<void> _initTutorialManager() async {
    _tutorialManager = await TutorialManager.create();
    if (mounted) {
      setState(() {
        _tutorialManagerInitialized = true;
      });

      // Now that we have the manager initialized, check if we should show the tutorial
      _tutorialManager.initializeWithDelay(context, mounted);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Continue to the summary screen
  void _continueToSummary(AssignmentProvider provider) {
    // Check if everything is assigned
    if (provider.unassignedAmount > 0.01) {
      // Show dialog about unassigned amount
      showUnassignedWarningDialog(
        context: context,
        unassignedAmount: provider.unassignedAmount,
        onSplitEvenly: provider.splitUnassignedAmountEvenly,
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

  // Show custom split dialog for an item
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
            alcoholTipPercentage: widget.alcoholTipPercentage,
            useDifferentAlcoholTip: widget.useDifferentAlcoholTip,
            isCustomTipAmount: widget.isCustomTipAmount,
          ),
      child: Consumer<AssignmentProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AssignmentAppBar(
              onBackPressed: () => Navigator.pop(context),
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
    final assignedAmount = widget.subtotal - provider.unassignedAmount;
    final assignedPercentage =
        widget.subtotal > 0
            ? (assignedAmount / widget.subtotal * 100).clamp(0.0, 100.0)
            : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${widget.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                      color: Colors.grey.shade600,
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
                              ? Colors.green.shade700
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
                  color: Colors.grey.shade200,
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
                          ? Colors.green.shade500
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
                          ? Colors.green.shade700
                          : colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the item list with the improved cards
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
