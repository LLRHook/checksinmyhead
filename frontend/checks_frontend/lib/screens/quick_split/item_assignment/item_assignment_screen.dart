import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'tutorial/tutorial_manager.dart';

// Widgets
import 'widgets/participant_selector.dart';
import 'widgets/item_card.dart';
import 'widgets/empty_items_view.dart';
import 'widgets/unassigned_amount_banner.dart';
import 'widgets/assignment_app_bar.dart';
import 'widgets/assignment_bottom_bar.dart';

// Dialogs
import 'dialogs/unassigned_warning_dialog.dart';
import 'dialogs/custom_split_dialog.dart';

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
      universalItemIcon: provider.universalItemIcon,
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
                // Participant selector at top
                ParticipantSelector(
                  participants: widget.participants,
                  selectedPerson: provider.selectedPerson,
                  birthdayPerson: provider.birthdayPerson,
                  personFinalShares: provider.personFinalShares,
                  onPersonSelected: provider.togglePersonSelection,
                  onBirthdayToggle: provider.toggleBirthdayPerson,
                  getPersonBillPercentage: provider.getPersonBillPercentage,
                ),

                // Unassigned amount indicator
                if (provider.unassignedAmount > 0.01)
                  UnassignedAmountBanner(
                    unassignedAmount: provider.unassignedAmount,
                    onSplitEvenly: provider.splitUnassignedAmountEvenly,
                  ),

                // Items list
                Expanded(
                  child:
                      widget.items.isEmpty
                          ? EmptyItemsView(
                            participants: widget.participants,
                            personFinalShares: provider.personFinalShares,
                            birthdayPerson: provider.birthdayPerson,
                            unassignedAmount: provider.unassignedAmount,
                            getPersonBillPercentage:
                                provider.getPersonBillPercentage,
                          )
                          : _buildItemsListView(provider),
                ),

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

  // Build the item list view when items have been added
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

        return ItemCard(
          item: item,
          assignedPercentage: assignedPercentage,
          selectedPerson: provider.selectedPerson,
          participants: widget.participants,
          universalItemIcon: provider.universalItemIcon,
          onAssign: provider.assignItem,
          onSplitEvenly: provider.splitItemEvenly,
          onShowCustomSplitDialog:
              (item, preselectedPeople) =>
                  _showCustomSplitDialog(item, preselectedPeople, provider),
          getAssignmentColor: AssignmentUtils.getAssignmentColor,
          isPersonAssignedToItem: AssignmentUtils.isPersonAssignedToItem,
          getAssignedPeopleForItem: AssignmentUtils.getAssignedPeopleForItem,
          balanceItemBetweenAssignees: provider.balanceItemBetweenAssignees,
        );
      },
    );
  }
}
