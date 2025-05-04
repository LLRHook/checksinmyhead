import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/recent_bills/components/loading_dots.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/empty_bills_state.dart';
import 'components/loading_bills_state.dart';
import 'components/recent_bill_card.dart';

class RecentBillsScreen extends StatefulWidget {
  const RecentBillsScreen({super.key});

  @override
  State<RecentBillsScreen> createState() => _RecentBillsScreenState();
}

class _RecentBillsScreenState extends State<RecentBillsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<RecentBillModel> _bills = [];

  // Add animation controller for refresh button
  late AnimationController _refreshAnimationController;

  // Track if refresh button was clicked
  bool _isRefreshButtonClicked = false;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1000,
      ), // 1 second for a full rotation
    );

    _loadBills();
  }

  @override
  void dispose() {
    // Dispose the animation controller when widget is disposed
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final bills = await RecentBillsManager.getRecentBills();

      // Add a small delay to make the loading state visible
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
          _isRefreshButtonClicked = false; // Reset refresh button state
        });

        // Stop the refresh animation when loading is complete
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshButtonClicked = false; // Reset refresh button state
        });

        // Stop the refresh animation if there's an error
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();

        _showErrorSnackBar('Failed to load recent bills');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.vibrate();

    final brightness = Theme.of(context).brightness;
    final snackBarBgColor =
        brightness == Brightness.dark
            ? const Color(0xFF3A0D0D) // Darker red for dark mode
            : Theme.of(context).colorScheme.error;

    final snackBarTextColor = Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: snackBarTextColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: snackBarTextColor)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width * 0.9,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: snackBarBgColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final scaffoldBgColor =
        brightness == Brightness.dark
            ? colorScheme.background
            : Colors.grey[50];

    final appBarBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final appBarIconColor = colorScheme.onSurface;

    final titleColor = colorScheme.onSurface;

    // Header colors
    final headerTextColor = Colors.white;
    final headerSecondaryTextColor = Colors.white.withOpacity(0.9);
    final headerIconBgColor = Colors.white.withOpacity(0.2);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          'Recent Bills',
          style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
        ),
        centerTitle: true,
        backgroundColor: appBarBgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarIconColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        actions: [
          // Refresh button with rotation animation
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshAnimationController,
              builder: (context, child) {
                // Only show rotation animation if refresh button was clicked
                if (_isRefreshButtonClicked) {
                  return Transform.rotate(
                    angle: _refreshAnimationController.value * 2.0 * 3.14159,
                    child: const Icon(Icons.refresh_outlined),
                  );
                } else {
                  return const Icon(Icons.refresh_outlined);
                }
              },
            ),
            onPressed: () {
              if (!_isRefreshButtonClicked && !_isLoading) {
                HapticFeedback.selectionClick();

                // Set flag to show animation
                setState(() {
                  _isRefreshButtonClicked = true;
                });

                // Start rotation animation
                _refreshAnimationController.reset();
                _refreshAnimationController.repeat();

                // Load bills
                _loadBills();
              }
            },
            tooltip: 'Refresh bills',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBills,
        color: colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Always show the header regardless of bill count
            _buildListHeader(
              headerTextColor,
              headerSecondaryTextColor,
              headerIconBgColor,
              colorScheme,
            ),

            // Content area - show loading state or content based on _isLoading
            if (_isLoading)
              const LoadingBillsState()
            else if (_bills.isEmpty)
              const EmptyBillsState()
            else
              _buildBillsList(),
          ],
        ),
      ),
    );
  }

  // Modified list header to show accurate bill count
  Widget _buildListHeader(
    Color headerTextColor,
    Color headerSecondaryTextColor,
    Color headerIconBgColor,
    ColorScheme colorScheme,
  ) {
    // Calculate total amount spent
    final double totalSpent = _bills.fold(0, (sum, bill) => sum + bill.total);

    final brightness = Theme.of(context).brightness;

    // Shadow color should be different for dark mode
    final shadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(
              0.5,
            ) // More prominent in dark mode
            : colorScheme.primary.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bill count with animated dots when loading
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: headerIconBgColor,
              shape: BoxShape.circle,
            ),
            child:
                _isLoading
                    ? _buildAnimatedDots(headerTextColor)
                    : Text(
                      '${_bills.length}',
                      style: TextStyle(
                        color: headerTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
          ),

          const SizedBox(width: 12),

          // Stats text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Bills',
                  style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        color: headerSecondaryTextColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: headerSecondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            height: 1.3,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Only your 30 latest bills are kept. ',
                            ),
                            TextSpan(text: '\n'),
                            TextSpan(
                              text: 'New ones bump the oldest ones out!',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total amount (only show when not loading and bills exist)
          if (!_isLoading && _bills.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                CurrencyFormatter.formatCurrency(totalSpent),
                style: TextStyle(
                  color: headerTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Create a new method for the animated dots
  // Create a new method for the animated dots
  // Create a new method for the animated dots
  Widget _buildAnimatedDots(Color dotColor) {
    return SizedBox(
      width: 24,
      height: 20,
      child: Center(
        child: LoadingDots(color: dotColor, size: 4.0, spacing: 3.0),
      ),
    );
  }

  Widget _buildBillsList() {
    // Sort bills by date (newest first)
    final sortedBills = List<RecentBillModel>.from(_bills)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children:
          sortedBills
              .map((bill) => RecentBillCard(bill: bill, onDeleted: _loadBills))
              .toList(),
    );
  }
}
