import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import 'bill_summary_screen.dart';

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

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
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

  @override
  void initState() {
    super.initState();
    _calculateInitialAssignments();
  }

  // Initialize with even distribution if no items are added
  // or items are added but not yet assigned
  void _calculateInitialAssignments() {
    setState(() {
      if (widget.items.isEmpty) {
        // If no items were entered, split subtotal evenly
        double evenShare = widget.subtotal / widget.participants.length;

        for (var person in widget.participants) {
          _personTotals[person] = evenShare;
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

  // Calculate each person's share of tax and tip based on their subtotal portion
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

  // Handle assigning an item to participants
  void _assignItem(BillItem item, Map<Person, double> newAssignments) {
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

  // Toggle birthday person status
  void _toggleBirthdayPerson(Person person) {
    setState(() {
      if (_birthdayPerson == person) {
        _birthdayPerson = null;
      } else {
        _birthdayPerson = person;
      }
      _calculateFinalShares();
    });
  }

  // Continue to the summary screen
  void _continueToSummary() {
    // Check if everything is assigned
    if (_unassignedAmount > 0.01) {
      // Show dialog about unassigned amount
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Unassigned Amount'),
              content: Text(
                'There\'s still \$${_unassignedAmount.toStringAsFixed(2)} unassigned. '
                'Would you like to split it evenly?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _splitUnassignedAmountEvenly();
                  },
                  child: const Text('Split Evenly'),
                ),
              ],
            ),
      );
      return;
    }

    // Navigate to summary screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => BillSummaryScreen(
              participants: widget.participants,
              personShares: _personFinalShares,
              items: widget.items,
              subtotal: widget.subtotal,
              tax: widget.tax,
              tipAmount: widget.tipAmount,
              total: widget.total,
              birthdayPerson: _birthdayPerson,
            ),
      ),
    );
  }

  // Split any unassigned amount evenly among participants
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

      _personTotals = newPersonTotals;
      _unassignedAmount = 0.0;
      _calculateFinalShares();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Items'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Participant selector at top
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a person to assign items:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.participants.length,
                    itemBuilder: (context, index) {
                      final person = widget.participants[index];
                      final isSelected = _selectedPerson == person;
                      final isBirthdayPerson = _birthdayPerson == person;

                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPerson = null;
                                  } else {
                                    _selectedPerson = person;
                                  }
                                });
                              },
                              onLongPress: () => _toggleBirthdayPerson(person),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: person.color,
                                    radius: 28,
                                    child: Text(
                                      person.name[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSelected ? 18 : 16,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: colorScheme.primary,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  if (isBirthdayPerson)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.cake,
                                          color: Colors.pink,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              person.name,
                              style: TextStyle(
                                fontWeight:
                                    isSelected || isBirthdayPerson
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '\$${(_personFinalShares[person] ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isBirthdayPerson
                                        ? Colors.green
                                        : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_birthdayPerson != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, size: 16, color: Colors.pink),
                        const SizedBox(width: 4),
                        Text(
                          '${_birthdayPerson!.name}\'s share will be split among others',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Unassigned amount indicator
          if (_unassignedAmount > 0.01)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Unassigned: \$${_unassignedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _splitUnassignedAmountEvenly,
                    child: const Text('Split Evenly'),
                  ),
                ],
              ),
            ),

          // Items list
          Expanded(
            child:
                widget.items.isEmpty
                    ? _buildEvenSplitView()
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(16),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name and price
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick assign buttons
                Row(
                  children: [
                    // Assign to selected person
                    if (_selectedPerson != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _assignItem(item, {_selectedPerson!: 100.0});
                          },
                          icon: const Icon(Icons.person, size: 18),
                          label: const Text('Assign to Selected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedPerson!.color.withOpacity(
                              0.2,
                            ),
                            foregroundColor: _selectedPerson!.color,
                            elevation: 0,
                          ),
                        ),
                      ),

                    // Split evenly button
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: _selectedPerson != null ? 8.0 : 0.0,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _splitItemEvenly(item, widget.participants);
                          },
                          icon: const Icon(Icons.groups, size: 18),
                          label: const Text('Split Evenly'),
                          style: ElevatedButton.styleFrom(elevation: 0),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Assignment indicators
                if (item.assignments.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),

                  const Text(
                    'Currently assigned to:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        item.assignments.entries.map((entry) {
                          final person = entry.key;
                          final percentage = entry.value;

                          return Chip(
                            label: Text(
                              '${person.name} (${percentage.toStringAsFixed(0)}%)',
                            ),
                            backgroundColor: person.color.withOpacity(0.2),
                            side: BorderSide(
                              color: person.color.withOpacity(0.3),
                            ),
                            labelStyle: TextStyle(
                              color: person.color.withAlpha(200),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                  ),
                ],

                // Custom split option
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    _showCustomSplitDialog(item);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Custom Split'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build the even split view when no items have been added
  Widget _buildEvenSplitView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Splitting bill evenly',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Since no items were added, the bill will be split evenly among ${_birthdayPerson != null ? 'all participants except ${_birthdayPerson!.name}' : 'all participants'}.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Each person pays:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  // Show each person's share
                  ...widget.participants.map((person) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: person.color,
                            radius: 14,
                            child: Text(
                              person.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            '\$${(_personFinalShares[person] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  _birthdayPerson == person
                                      ? Colors.green
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Pro tip about item entry
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pro Tip',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Next time, try adding individual items to assign them to specific people for more precise splitting.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Birthday person explanation
          if (_birthdayPerson != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pink.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake, color: Colors.pink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_birthdayPerson!.name}\'s share has been evenly split among the other participants.',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Show dialog for custom item splitting
  void _showCustomSplitDialog(BillItem item) {
    // Create a copy of current assignments to work with
    Map<Person, double> workingAssignments = Map.from(item.assignments);

    // Fill in missing participants with 0%
    for (var person in widget.participants) {
      workingAssignments.putIfAbsent(person, () => 0.0);
    }

    // Calculate total percentage assigned
    double totalPercentage = workingAssignments.values.fold(
      0,
      (sum, value) => sum + value,
    );

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text('Split "${item.name}"'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Total percentage indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color:
                              totalPercentage == 100.0
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Total: ${totalPercentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    totalPercentage == 100.0
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                              ),
                            ),
                            const Spacer(),
                            if (totalPercentage != 100.0)
                              Text(
                                totalPercentage > 100.0
                                    ? 'Remove ${(totalPercentage - 100.0).toStringAsFixed(0)}%'
                                    : 'Add ${(100.0 - totalPercentage).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      totalPercentage > 100.0
                                          ? Colors.red.shade800
                                          : Colors.orange.shade800,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Person sliders
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.participants.length,
                          itemBuilder: (context, index) {
                            final person = widget.participants[index];
                            final percentage =
                                workingAssignments[person] ?? 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: person.color,
                                      radius: 12,
                                      child: Text(
                                        person.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      person.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${percentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                // Percentage slider
                                Slider(
                                  value: percentage,
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  activeColor: person.color,
                                  label: percentage.toStringAsFixed(0),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      workingAssignments[person] = value;
                                      totalPercentage = workingAssignments
                                          .values
                                          .fold(0, (sum, val) => sum + val);
                                    });
                                  },
                                ),

                                if (index < widget.participants.length - 1)
                                  const Divider(),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Quick fix for minor rounding issues
                      if ((totalPercentage > 99.0 && totalPercentage < 100.0) ||
                          (totalPercentage > 100.0 &&
                              totalPercentage < 101.0)) {
                        // Adjust values to make exactly 100%
                        var entries = workingAssignments.entries.toList();
                        entries.sort((a, b) => b.value.compareTo(a.value));

                        if (entries.isNotEmpty && entries[0].value > 0) {
                          double diff = 100.0 - totalPercentage;
                          workingAssignments[entries[0].key] =
                              (workingAssignments[entries[0].key] ?? 0.0) +
                              diff;
                          totalPercentage = 100.0;
                        }
                      }

                      if (totalPercentage == 100.0) {
                        Navigator.pop(context);
                        _assignItem(item, workingAssignments);
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Total percentage must be 100%'),
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
