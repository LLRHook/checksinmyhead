import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '../item_assignment/item_assignment_screen.dart';

// Models
import 'models/bill_data.dart';

// Widgets
import 'widgets/participant_avatars.dart';
import 'widgets/bill_total_section.dart';
import 'widgets/tip_options_section.dart';
import 'widgets/items_section.dart';
import 'widgets/bill_summary_section.dart';
import 'widgets/continue_button.dart';

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

  void _continueToItemAssignment() {
    if (_billData.subtotal > 0) {
      // Check if items have been added and if they match the subtotal
      if (_billData.items.isNotEmpty &&
          _billData.itemsTotal < _billData.subtotal) {
        // Show warning dialog that items don't match subtotal
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Items Don\'t Match Subtotal'),
                content: Text(
                  'Your added items total \$${_billData.itemsTotal.toStringAsFixed(2)}, but your subtotal is \$${_billData.subtotal.toStringAsFixed(2)}. Do you want to continue anyway, or add more items?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Provide feedback
                      HapticFeedback.selectionClick();
                    },
                    child: const Text('Add More Items'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Provide feedback
                      HapticFeedback.mediumImpact();
                      _navigateToItemAssignment();
                    },
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
        );
      } else {
        // Provide haptic feedback for continuing
        HapticFeedback.mediumImpact();

        // All good, navigate to the next screen
        _navigateToItemAssignment();
      }
    } else {
      // Show error for missing subtotal
      _showSnackBar('Please enter a subtotal amount');
    }
  }

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
              alcoholTipPercentage: _billData.alcoholTipPercentage,
              useDifferentAlcoholTip: _billData.useDifferentTipForAlcohol,
              isCustomTipAmount: _billData.useCustomTipAmount,
            ),
      ),
    );
  }

  // Show a premium styled snackbar with haptic feedback
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
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Participant avatars with premium styling
              ParticipantAvatars(participants: widget.participants),

              const SizedBox(height: 20),

              // Bill totals section
              const BillTotalSection(),

              const SizedBox(height: 20),

              // Tip section
              const TipOptionsSection(),

              const SizedBox(height: 20),

              // Item entry section
              ItemsSection(showSnackBar: _showSnackBar),

              const SizedBox(height: 20),

              // Bill summary with premium styling
              const BillSummarySection(),

              const SizedBox(height: 24),

              // Premium continue button
              ContinueButton(onPressed: _continueToItemAssignment),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
