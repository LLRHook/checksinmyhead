import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

// Import refactored components
import 'models/bill_summary_data.dart';
import 'widgets/bill_total_card.dart';
import 'widgets/split_overview.dart';
import 'widgets/person_card.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/share_options_sheet.dart';
import 'utils/share_utils.dart';

class BillSummaryScreen extends StatefulWidget {
  final List<Person> participants;
  final Map<Person, double> personShares;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final Person? birthdayPerson;
  final double tipPercentage;
  final bool isCustomTipAmount;

  const BillSummaryScreen({
    super.key,
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
    this.tipPercentage = 0.0,
    this.isCustomTipAmount = false,
  });

  @override
  State<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends State<BillSummaryScreen> {
  // Share options
  late ShareOptions _shareOptions;

  // Bill summary data
  late BillSummaryData _summaryData;

  @override
  void initState() {
    super.initState();

    // Initialize share options
    _shareOptions = ShareOptions();

    // Initialize bill summary data
    _summaryData = BillSummaryData(
      participants: widget.participants,
      personShares: widget.personShares,
      items: widget.items,
      subtotal: widget.subtotal,
      tax: widget.tax,
      tipAmount: widget.tipAmount,
      total: widget.total,
      birthdayPerson: widget.birthdayPerson,
      tipPercentage: widget.tipPercentage,
      isCustomTipAmount: widget.isCustomTipAmount,
    );
  }

  void _shareBillSummary() {
    // Generate formatted bill summary text
    final String summary = ShareUtils.generateShareText(
      participants: widget.participants,
      personShares: widget.personShares,
      items: widget.items,
      subtotal: widget.subtotal,
      tax: widget.tax,
      tipAmount: widget.tipAmount,
      total: widget.total,
      birthdayPerson: widget.birthdayPerson,
      tipPercentage: widget.tipPercentage,
      isCustomTipAmount: widget.isCustomTipAmount,
      includeItemsInShare: _shareOptions.includeItemsInShare,
      includePersonItemsInShare: _shareOptions.includePersonItemsInShare,
      hideBreakdownInShare: _shareOptions.hideBreakdownInShare,
    );

    // Share the summary
    ShareUtils.shareBillSummary(context: context, summary: summary);
  }

  void _promptShareOptions() {
    ShareOptionsSheet.show(
      context: context,
      initialOptions: _shareOptions,
      onOptionsChanged: (updatedOptions) {
        setState(() {
          _shareOptions = updatedOptions;
        });
      },
      onShareTap: _shareBillSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = _summaryData.sortedParticipants;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Bill Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Bill overview card with integrated items
                      BillTotalCard(data: _summaryData),

                      const SizedBox(height: 24),

                      // Split overview
                      SplitOverview(data: _summaryData),

                      const SizedBox(height: 24),

                      // Individual shares
                      Text(
                        'Individual Shares',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      ...sortedParticipants.map(
                        (person) =>
                            PersonCard(person: person, data: _summaryData),
                      ),

                      // Add space at bottom for button
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom action bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomBar(
              onShareTap: _promptShareOptions,
              onDoneTap: () => DoneButtonHandler.handleDone(context),
            ),
          ),
        ],
      ),
    );
  }
}
