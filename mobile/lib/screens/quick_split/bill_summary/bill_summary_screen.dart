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

import 'package:checks_frontend/screens/settings/services/settings_manager.dart';
import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

// Import refactored components
import 'models/bill_summary_data.dart';
import 'widgets/bill_total_card.dart';
import 'widgets/person_card.dart';
import 'widgets/bottom_bar.dart';
import 'utils/share_utils.dart';

/// BillSummaryScreen - Displays a complete bill breakdown with sharing options
///
/// This screen shows the final bill summary, including total amount, item breakdown,
/// and individual shares for each participant. It allows users to share the bill
/// via the platform's share sheet and save the bill for later reference.
///
/// Inputs:
///   - Participant list and their respective shares
///   - Bill items with prices and assignments
///   - Bill totals (subtotal, tax, tip, final total)
///   - Tip configuration (percentage or custom amount)
///   - Optional birthday person who pays nothing
///
/// Side effects:
///   - Saves share preferences to persistent storage
///   - Can trigger system share sheet
///   - Can save bill to recent bills database
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
  bool _isLoading = true;

  // Bill summary data
  late BillSummaryData _summaryData;

  @override
  void initState() {
    super.initState();

    // Initialize with default share options until loaded from storage
    _shareOptions = ShareOptions();

    // Consolidate bill data into a single object for easier passing to widgets
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

    // Asynchronously load saved share options
    _loadShareOptions();
  }

  /// Loads share options from persistent storage
  Future<void> _loadShareOptions() async {
    final options = await SettingsManager.getShareOptions();

    // Only update state if widget is still mounted
    if (mounted) {
      setState(() {
        _shareOptions = options;
        _isLoading = false;
      });
    }
  }

  /// Generates and shares the bill summary via platform share sheet
  void _shareBillSummary() async {
    // Generate formatted bill summary text with current options
    final String summary = await ShareUtils.generateShareText(
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

    // Trigger platform share sheet with the generated summary
    ShareUtils.shareBillSummary(summary: summary);
  }

  /// Shows the share options sheet for customizing share content
  void _promptShareOptions() {
    ShareOptionsSheet.show(
      context: context,
      initialOptions: _shareOptions,
      onOptionsChanged: (updatedOptions) {
        setState(() {
          _shareOptions = updatedOptions;
        });
        // Persist the updated options for future sessions
        SettingsManager.saveShareOptions(updatedOptions);
      },
      onShareTap: _shareBillSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = _summaryData.sortedParticipants;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for light/dark mode support
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final appBarColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final titleColor = colorScheme.onSurface;

    // Only override text color in dark mode
    final sectionTitleColor =
        brightness == Brightness.dark
            ? Colors.white
            : null; // Use default for light mode

    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Bill Summary',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
        centerTitle: true,
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Main scrollable content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Bill total card shows overall bill with items breakdown
                      BillTotalCard(data: _summaryData),

                      const SizedBox(height: 16),

                      // Individual shares section
                      Text(
                        'Individual Shares',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: sectionTitleColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Generate a PersonCard for each participant
                      ...sortedParticipants.map(
                        (person) =>
                            PersonCard(person: person, data: _summaryData),
                      ),

                      // Extra space to ensure content isn't hidden behind the bottom bar
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomBar(
              onShareTap: _promptShareOptions,
              onDoneTap: () async {
                await DoneButtonHandler.handleDone(context, data: _summaryData);
              },
              data:
                  _summaryData, // Pass the entire data object instead of individual props
            ),
          ),
        ],
      ),
    );
  }
}
