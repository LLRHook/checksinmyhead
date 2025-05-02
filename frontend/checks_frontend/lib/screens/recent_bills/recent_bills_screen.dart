import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/empty_bills_state.dart';
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

      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

    // Loading screen colors
    final loadingTextColor = colorScheme.onSurface;

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
                return Transform.rotate(
                  angle:
                      _refreshAnimationController.value *
                      2.0 *
                      3.14159, // Full 360-degree rotation
                  child: const Icon(Icons.refresh_outlined),
                );
              },
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              // Start animation
              _refreshAnimationController.reset();
              _refreshAnimationController.forward();
              _loadBills();
            },
            tooltip: 'Refresh bills',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBills,
        color: colorScheme.primary,
        child:
            _bills.isEmpty && !_isLoading
                ? const EmptyBillsState()
                : _buildBillsList(
                  headerTextColor,
                  headerSecondaryTextColor,
                  headerIconBgColor,
                  colorScheme,
                ),
      ),
    );
  }

  Widget _buildBillsList(
    Color headerTextColor,
    Color headerSecondaryTextColor,
    Color headerIconBgColor,
    ColorScheme colorScheme,
  ) {
    // Sort bills by date (newest first)
    final sortedBills = List<RecentBillModel>.from(_bills)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: sortedBills.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header showing total bill count
          return _buildListHeader(
            headerTextColor,
            headerSecondaryTextColor,
            headerIconBgColor,
            colorScheme,
          );
        }

        // Adjust index to account for the header
        final billIndex = index - 1;
        return RecentBillCard(
          bill: sortedBills[billIndex],
          onDeleted: _loadBills,
        );
      },
    );
  }

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
          // Bill count
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: headerIconBgColor,
              shape: BoxShape.circle,
            ),
            child: Text(
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
                Text(
                  'Total split: ${CurrencyFormatter.formatCurrency(totalSpent)}',
                  style: TextStyle(
                    color: headerSecondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: headerSecondaryTextColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checkmate only stores your last 30 bills.',
                      style: TextStyle(
                        color: headerSecondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
