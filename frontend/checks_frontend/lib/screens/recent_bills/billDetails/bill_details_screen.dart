import 'package:checks_frontend/screens/recent_bills/components/bill_summary_card.dart';
import 'package:checks_frontend/screens/recent_bills/components/bottom_bar.dart';
import 'package:checks_frontend/screens/recent_bills/components/participants_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/utils/settings_manager.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';

// Local imports
import 'utils/bill_calculations.dart';
import 'utils/share_utils.dart';

class BillDetailsScreen extends StatefulWidget {
  final RecentBillModel bill;

  const BillDetailsScreen({Key? key, required this.bill}) : super(key: key);

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  // Share options
  late ShareOptions _shareOptions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize with default share options until loaded
    _shareOptions = ShareOptions(
      includeItemsInShare: true,
      includePersonItemsInShare: true,
      hideBreakdownInShare: false,
    );

    // Load share options from database
    _loadShareOptions();
  }

  Future<void> _loadShareOptions() async {
    try {
      final options = await SettingsManager.getShareOptions();
      if (mounted) {
        setState(() {
          _shareOptions = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If there's an error loading options, use defaults and continue
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _promptShareOptions() {
    ShareOptionsSheet.show(
      context: context,
      initialOptions: _shareOptions,
      onOptionsChanged: (updatedOptions) {
        setState(() {
          _shareOptions = updatedOptions;
        });
        // Save updated options to database
        SettingsManager.saveShareOptions(updatedOptions);
      },
      onShareTap: _shareBillSummary,
    );
  }

  void _shareBillSummary() {
    // Use the BillCalculations utility to prepare data
    final billCalculations = BillCalculations(widget.bill);

    // Convert the saved bill data back to the format needed for sharing
    final String summary = ShareUtils.generateShareText(
      participants:
          widget.bill.participantNames
              .map((name) => Person(name: name, color: widget.bill.color))
              .toList(),
      personShares: billCalculations.generatePersonShares(),
      items: billCalculations.generateBillItems(),
      subtotal: widget.bill.subtotal,
      tax: widget.bill.tax,
      tipAmount: widget.bill.tipAmount,
      total: widget.bill.total,
      birthdayPerson:
          null, // Assuming birthday person isn't stored in recent bills
      tipPercentage: widget.bill.tipPercentage,
      isCustomTipAmount: false, // Assuming this isn't stored
      includeItemsInShare: _shareOptions.includeItemsInShare,
      includePersonItemsInShare: _shareOptions.includePersonItemsInShare,
      hideBreakdownInShare: _shareOptions.hideBreakdownInShare,
    );

    // Share the summary
    ShareUtils.shareBillSummary(context: context, summary: summary);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    // Create a single instance of BillCalculations for all child widgets
    final billCalculations = BillCalculations(widget.bill);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // App bar with back and share buttons
            _buildAppBar(context),

            // Expanded content with header and scrollable cards
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Header is now sticky at the top of the scroll
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverHeaderDelegate(
                      minHeight: 120,
                      maxHeight: 140,
                      child: _buildHeader(context),
                    ),
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Bill details card
                        BillSummaryCard(bill: widget.bill),

                        const SizedBox(height: 16),

                        // Enhanced participants card (now includes item details)
                        ParticipantsCard(
                          bill: widget.bill,
                          calculations: billCalculations,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Bottom Action Bar
      bottomNavigationBar: BottomBar(onShareTap: _promptShareOptions),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),

          const Spacer(),

          // Title
          Text(
            'Bill Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),

          const Spacer(),

          // Share button
          IconButton(
            icon: Icon(Icons.ios_share, color: colorScheme.primary),
            onPressed: _promptShareOptions,
            tooltip: 'Share bill',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.bill.formattedDate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total amount
          Text(
            CurrencyFormatter.formatCurrency(widget.bill.total),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for sticky header
class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
