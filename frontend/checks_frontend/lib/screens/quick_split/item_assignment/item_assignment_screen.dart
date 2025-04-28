import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import '../tutorial/tutorial_manager.dart';
import 'widgets/participant_selector.dart';
import 'widgets/item_card.dart';
import 'widgets/empty_items_view.dart';
import 'widgets/unassigned_amount_banner.dart';
import 'dialogs/unassigned_warning_dialog.dart';
import 'dialogs/custom_split_dialog.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/bill_summary_screen.dart';

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
  });

  @override
  State<ItemAssignmentScreen> createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen>
    with SingleTickerProviderStateMixin {
  // Maps each person to their total assigned amount (before tax and tip)
  Map<Person, double> _personTotals = {};
  // Maps each person to their final share (including tax and tip)
  Map<Person, double> _personFinalShares = {};
  // Unassigned portion of the bill subtotal
  double _unassignedAmount = 0.0;
  // Currently selected person for quick assignment
  Person? _selectedPerson;
  // Special case: birthday person who doesn't pay
  Person? _birthdayPerson;
  // Animation controller for UI elements
  late AnimationController _animationController;
  // Universal food/drink icon
  final IconData _universalItemIcon = Icons.restaurant_menu;

  late TutorialManager _tutorialManager;
  bool _tutorialManagerInitialized = false;

  @override
  void initState() {
    super.initState();
    _calculateInitialAssignments();
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

  // Get background color based on assignments
  Color _getAssignmentColor(BillItem item, Color defaultColor) {
    // If fully assigned to one person, use their color
    if (item.assignments.length == 1 &&
        item.assignments.values.first == 100.0) {
      return item.assignments.keys.first.color.withOpacity(0.2);
    }
    // If partially assigned, use a neutral color
    return defaultColor;
  }

  // Check if a person is already assigned to an item
  bool _isPersonAssignedToItem(BillItem item, Person person) {
    return item.assignments.containsKey(person) &&
        item.assignments[person]! > 0;
  }

  // Get all assigned people for an item
  List<Person> _getAssignedPeopleForItem(BillItem item) {
    return item.assignments.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
  }

  // Balance an item between current assignees
  void _balanceItemBetweenAssignees(
    BillItem item,
    List<Person> assignedPeople,
  ) {
    if (assignedPeople.isEmpty) return;

    Map<Person, double> newAssignments = {};
    double percentage = 100.0 / assignedPeople.length;

    for (var person in assignedPeople) {
      newAssignments[person] = percentage;
    }

    _assignItem(item, newAssignments);
  }

  // Initialize with even distribution if no items are added
  // or items are added but not yet assigned
  void _calculateInitialAssignments() {
    setState(() {
      if (widget.items.isEmpty) {
        // If no items were entered, split subtotal evenly
        // BUT we need to consider birthday person here
        int payingPeople = widget.participants.length;
        if (_birthdayPerson != null) payingPeople--;

        double evenShare =
            payingPeople > 0 ? widget.subtotal / payingPeople : 0.0;

        for (var person in widget.participants) {
          if (_birthdayPerson == person) {
            _personTotals[person] = 0.0; // Birthday person pays nothing
          } else {
            _personTotals[person] = evenShare; // Everyone else pays more
          }
        }

        _unassignedAmount = 0.0;
      } else {
        // If items were entered but not assigned, all amount is unassigned
        _unassignedAmount = widget.subtotal;

        for (var person in widget.participants) {
          _personTotals[person] = 0.0;
        }
      }

      _calculateFinalShares();
    });
  }

  // Calculate person's percentage of the total bill
  double _getPersonBillPercentage(Person person) {
    final total = widget.total > 0 ? widget.total : 1.0;
    final share = _personFinalShares[person] ?? 0.0;
    return (share / total).clamp(0.0, 1.0);
  }

  // Handle assigning an item to participants
  void _assignItem(BillItem item, Map<Person, double> newAssignments) {
    HapticFeedback.mediumImpact(); // Provide haptic feedback

    setState(() {
      // Update item assignments
      item.assignments = newAssignments;

      // Recalculate person totals
      Map<Person, double> newPersonTotals = {};
      for (var person in widget.participants) {
        double personTotal = 0.0;

        // Sum all item assignments for this person
        for (var billItem in widget.items) {
          personTotal += billItem.amountForPerson(person);
        }

        newPersonTotals[person] = personTotal;
      }

      // Calculate unassigned amount
      double assignedTotal = newPersonTotals.values.fold(
        0,
        (sum, amount) => sum + amount,
      );
      _unassignedAmount = widget.subtotal - assignedTotal;

      _personTotals = newPersonTotals;
      _calculateFinalShares();
    });
  }

  // Evenly split an item among selected participants
  void _splitItemEvenly(BillItem item, List<Person> people) {
    if (people.isEmpty) return;

    Map<Person, double> newAssignments = {};
    double percentage = 100.0 / people.length;

    for (var person in people) {
      newAssignments[person] = percentage;
    }

    _assignItem(item, newAssignments);
  }

  // Replace the existing _toggleBirthdayPerson method with this one:

  void _toggleBirthdayPerson(Person person) {
    setState(() {
      if (_birthdayPerson == person) {
        _birthdayPerson = null;
        HapticFeedback.mediumImpact();
      } else {
        _birthdayPerson = person;
        // If the selected person is now the birthday person, deselect them
        if (_selectedPerson == person) {
          _selectedPerson = null;
        }

        // Important: Unassign all items from the birthday person
        _unassignItemsFromBirthdayPerson(person);

        HapticFeedback.mediumImpact();
      }

      // Important: If no items, recalculate initial assignments to handle birthday person
      if (widget.items.isEmpty) {
        _calculateInitialAssignments();
      } else {
        _calculateFinalShares();
      }
    });
  }

  // Also update the unassign method to ensure it's working properly

  // New helper method to unassign items from birthday person
  void _unassignItemsFromBirthdayPerson(Person birthdayPerson) {
    // Keep track of changes to avoid unnecessary updates
    bool changesDetected = false;

    // Go through each item and remove the birthday person's assignments
    for (var item in widget.items) {
      if (item.assignments.containsKey(birthdayPerson)) {
        // Get the percentage that was assigned to birthday person
        double birthdayPersonPercentage =
            item.assignments[birthdayPerson] ?? 0.0;

        if (birthdayPersonPercentage > 0) {
          changesDetected = true;

          // Remove the birthday person from assignments
          Map<Person, double> newAssignments = Map.from(item.assignments);
          newAssignments.remove(birthdayPerson);

          // If there are other people assigned to this item, redistribute
          if (newAssignments.isNotEmpty) {
            // Redistribute the percentage proportionally among remaining assignees
            double totalRemaining = newAssignments.values.fold(
              0.0,
              (sum, value) => sum + value,
            );

            if (totalRemaining > 0) {
              // Scale factor to redistribute
              double scaleFactor = 100.0 / totalRemaining;

              // Rescale everyone else's percentages
              newAssignments.forEach((key, value) {
                newAssignments[key] = value * scaleFactor;
              });
            }
          }

          // Update item assignments
          item.assignments = newAssignments;
        }
      }
    }

    if (changesDetected) {
      // Recalculate person totals if changes were made
      Map<Person, double> newPersonTotals = {};
      for (var person in widget.participants) {
        double personTotal = 0.0;

        // Sum all item assignments for this person
        for (var billItem in widget.items) {
          personTotal += billItem.amountForPerson(person);
        }

        newPersonTotals[person] = personTotal;
      }

      // Calculate unassigned amount
      double assignedTotal = newPersonTotals.values.fold(
        0,
        (sum, amount) => sum + amount,
      );
      _unassignedAmount = widget.subtotal - assignedTotal;

      _personTotals = newPersonTotals;
    }
  }

  void _calculateFinalShares() {
    Map<Person, double> newShares = {};

    // Calculate total assigned amount
    double totalAssigned = _personTotals.values.fold(
      0,
      (sum, amount) => sum + amount,
    );

    // Calculate percentage of bill for each person (if anything is assigned)
    if (totalAssigned > 0) {
      for (var person in widget.participants) {
        if (_birthdayPerson == person) {
          // Birthday person pays nothing
          newShares[person] = 0.0;
          continue;
        }

        double personSubtotal = _personTotals[person] ?? 0.0;
        // Adjust the percentage calculation to exclude the birthday person from the total
        double personPercentage = personSubtotal / totalAssigned;

        // Calculate person's share of tax and tip
        double personTax = widget.tax * personPercentage;
        double personTip = widget.tipAmount * personPercentage;

        // Add to final share
        newShares[person] = personSubtotal + personTax + personTip;
      }
    } else {
      // If nothing assigned yet, split everything evenly except for birthday person
      int payingPeople = widget.participants.length;
      if (_birthdayPerson != null) payingPeople--;

      if (payingPeople > 0) {
        double evenShare = widget.total / payingPeople;

        for (var person in widget.participants) {
          if (_birthdayPerson == person) {
            newShares[person] = 0.0;
          } else {
            newShares[person] = evenShare;
          }
        }
      }
    }

    setState(() {
      _personFinalShares = newShares;
    });
  }

  // Continue to the summary screen
  void _continueToSummary() {
    // Check if everything is assigned
    if (_unassignedAmount > 0.01) {
      // Show dialog about unassigned amount
      showUnassignedWarningDialog(
        context: context,
        unassignedAmount: _unassignedAmount,
        onSplitEvenly: _splitUnassignedAmountEvenly,
      );
      return;
    }

    // Navigate to summary screen with animation
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => BillSummaryScreen(
              participants: widget.participants,
              personShares: _personFinalShares,
              items: widget.items,
              subtotal: widget.subtotal,
              tax: widget.tax,
              tipAmount: widget.tipAmount,
              total: widget.total,
              birthdayPerson: _birthdayPerson,
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

  // Split any unassigned amount evenly among participants
  // Replace your current _splitUnassignedAmountEvenly method with this one:

  void _splitUnassignedAmountEvenly() {
    if (_unassignedAmount <= 0) return;

    setState(() {
      // Count paying participants (exclude birthday person)
      int payingPeople = widget.participants.length;
      if (_birthdayPerson != null) payingPeople--;

      if (payingPeople <= 0) return;

      // Calculate even share of unassigned amount
      double evenShare = _unassignedAmount / payingPeople;

      // Add to each person's total
      Map<Person, double> newPersonTotals = Map.from(_personTotals);
      for (var person in widget.participants) {
        if (person != _birthdayPerson) {
          newPersonTotals[person] =
              (newPersonTotals[person] ?? 0.0) + evenShare;
        }
      }

      // KEY FIX: Create a fake item to represent the unassigned amount and assign it properly
      if (widget.items.isEmpty) {
        // If no items, create dummy assignments in personTotals
        _personTotals = newPersonTotals;
      } else {
        // If there are items but some amount is unassigned,
        // we need to assign that amount evenly to all existing items

        // Calculate what percentage of each item is currently unassigned
        double totalUnassignedPercentage = 0;
        for (var item in widget.items) {
          double assignedPercentage = item.assignments.values.fold(
            0.0,
            (sum, value) => sum + value,
          );
          totalUnassignedPercentage += (100.0 - assignedPercentage);
        }

        // For each item, assign its unassigned portion evenly
        for (var item in widget.items) {
          // Get current assigned percentage
          double currentAssignedPercentage = item.assignments.values.fold(
            0.0,
            (sum, value) => sum + value,
          );

          // Skip if item is already fully assigned
          if (currentAssignedPercentage >= 100.0) continue;

          // Calculate unassigned percentage for this item
          double itemUnassignedPercentage = 100.0 - currentAssignedPercentage;

          // Create a copy of current assignments
          Map<Person, double> newAssignments = Map.from(item.assignments);

          // For each paying person, add their share of the unassigned percentage
          for (var person in widget.participants) {
            if (person != _birthdayPerson) {
              // Calculate this person's share of the unassigned percentage
              double personShareOfUnassigned =
                  itemUnassignedPercentage / payingPeople;

              // Add to their current assignment (or set if not already assigned)
              newAssignments[person] =
                  (newAssignments[person] ?? 0.0) + personShareOfUnassigned;
            }
          }

          // Update the item's assignments
          item.assignments = newAssignments;
        }

        // Recalculate person totals based on the updated item assignments
        newPersonTotals = {};
        for (var person in widget.participants) {
          double personTotal = 0.0;

          // Sum all item assignments for this person
          for (var billItem in widget.items) {
            personTotal += billItem.amountForPerson(person);
          }

          newPersonTotals[person] = personTotal;
        }

        _personTotals = newPersonTotals;
      }

      _unassignedAmount = 0.0;
      _calculateFinalShares();

      // Add a success sound or animation here
      HapticFeedback.mediumImpact();
    });
  }

  // Show custom split dialog for an item
  void _showCustomSplitDialog(BillItem item, List<Person> preselectedPeople) {
    showCustomSplitDialog(
      context: context,
      item: item,
      participants: widget.participants,
      onAssign: _assignItem,
      universalItemIcon: _universalItemIcon,
      preselectedPeople: preselectedPeople,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assign Items',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_tutorialManagerInitialized)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                _tutorialManager.showTutorial(context);
              },
              tooltip: 'Show Tutorial',
            ),
        ],
      ),
      body: Column(
        children: [
          // Participant selector at top
          ParticipantSelector(
            participants: widget.participants,
            selectedPerson: _selectedPerson,
            birthdayPerson: _birthdayPerson,
            personFinalShares: _personFinalShares,
            onPersonSelected: (person) {
              setState(() {
                if (_selectedPerson == person) {
                  _selectedPerson = null;
                } else {
                  _selectedPerson = person;
                  HapticFeedback.selectionClick();
                }
              });
            },
            onBirthdayToggle: _toggleBirthdayPerson,
            getPersonBillPercentage: _getPersonBillPercentage,
          ),

          // Unassigned amount indicator
          if (_unassignedAmount > 0.01)
            UnassignedAmountBanner(
              unassignedAmount: _unassignedAmount,
              onSplitEvenly: () {
                _splitUnassignedAmountEvenly();
              },
            ),

          // Items list
          Expanded(
            child:
                widget.items.isEmpty
                    ? EmptyItemsView(
                      participants: widget.participants,
                      personFinalShares: _personFinalShares,
                      birthdayPerson: _birthdayPerson,
                      unassignedAmount: _unassignedAmount,
                      getPersonBillPercentage: _getPersonBillPercentage,
                    )
                    : _buildItemsListView(),
          ),

          // Bottom control bar with continue button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Bill total info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total Bill',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '\$${widget.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Continue button
                ElevatedButton(
                  onPressed: _continueToSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 2,
                    shadowColor: colorScheme.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the item list view when items have been added
  Widget _buildItemsListView() {
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
          selectedPerson: _selectedPerson,
          participants: widget.participants,
          universalItemIcon: _universalItemIcon,
          onAssign: _assignItem,
          onSplitEvenly: _splitItemEvenly,
          onShowCustomSplitDialog: _showCustomSplitDialog,
          getAssignmentColor: _getAssignmentColor,
          isPersonAssignedToItem: _isPersonAssignedToItem,
          getAssignedPeopleForItem: _getAssignedPeopleForItem,
          balanceItemBetweenAssignees: _balanceItemBetweenAssignees,
        );
      },
    );
  }
}
