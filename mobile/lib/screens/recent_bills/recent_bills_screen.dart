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

  // Add this method to your RecentBillsScreen class
  void _showDeleteConfirmation() {
    // Provide haptic feedback when opening modal
    HapticFeedback.mediumImpact();

    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define colors based on theme
    final backgroundColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white;

    final warningColor =
        brightness == Brightness.dark
            ? Color(0xFF6D0D12) // Deeper red for dark mode
            : Color(0xFFFDECEE); // Light red background for light mode

    final warningTextColor =
        brightness == Brightness.dark
            ? Color(0xFFFF8282) // Lighter red text for dark mode
            : Color(0xFFB3261E); // Darker red text for light mode

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 1.0, end: 0.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * value),
              child: Opacity(opacity: 1 - value, child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Warning icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: warningColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: warningTextColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Delete All Bills',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    'This will permanently delete all ${_bills.length} bills from your history. This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Action buttons with modern styling
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            HapticFeedback.lightImpact();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Delete button
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            // Close modal
                            Navigator.of(context).pop();

                            // Strong haptic feedback for destructive action
                            HapticFeedback.heavyImpact();

                            // Perform delete action
                            setState(() {
                              _isLoading = true;
                            });

                            // Call the clearAllBills method and then reload
                            RecentBillsManager.clearAllBills().then((_) {
                              _loadBills();
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer,
                            foregroundColor: colorScheme.onErrorContainer,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Delete All',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Extra padding for bottom safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
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
        brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50];

    final appBarBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final appBarIconColor = colorScheme.onSurface;

    final titleColor = colorScheme.onSurface;

    // Header colors
    final headerTextColor = Colors.white;
    final headerSecondaryTextColor = Colors.white.withValues(alpha: .9);
    final headerIconBgColor = Colors.white.withValues(alpha: .2);

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
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            color: colorScheme.error,
            onPressed: () {
              if (!_isRefreshButtonClicked &&
                  !_isLoading &&
                  _bills.isNotEmpty) {
                HapticFeedback.selectionClick();
                _showDeleteConfirmation();
              }
            },
          ),

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
    final brightness = Theme.of(context).brightness;

    // Shadow color should be different for dark mode
    final shadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(
              alpha: 0.5,
            ) // More prominent in dark mode
            : colorScheme.primary.withValues(alpha: .3);

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
        ],
      ),
    );
  }

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
