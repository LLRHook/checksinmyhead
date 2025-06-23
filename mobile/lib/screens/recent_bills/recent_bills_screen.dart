// Spliq: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/recent_bills/components/loading_dots.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/empty_bills_state.dart';
import 'components/loading_bills_state.dart';
import 'components/recent_bill_card.dart';

/// RecentBillsScreen
///
/// A screen that displays a user's saved bill history, with functionality
/// for viewing, refreshing, and managing saved bills.
///
/// Features:
/// - Displays a list of recent bills in chronological order
/// - Pull-to-refresh support for updating the bill list
/// - Loading states with animated indicators
/// - Empty state when no bills exist
/// - Actions for deleting individual bills or all bills
/// - Haptic feedback for improved user experience
/// - Theme-aware styling that adapts to light/dark mode
///
/// This screen serves as the central hub for accessing bill history
/// and provides entry points to detailed bill views.
class RecentBillsScreen extends StatefulWidget {
  const RecentBillsScreen({super.key});

  @override
  State<RecentBillsScreen> createState() => _RecentBillsScreenState();
}

class _RecentBillsScreenState extends State<RecentBillsScreen>
    with SingleTickerProviderStateMixin {
  /// Flag indicating whether bills are currently loading
  bool _isLoading = true;

  /// List of bill models retrieved from storage
  List<RecentBillModel> _bills = [];

  /// Controls the rotation animation for the refresh button
  late AnimationController _refreshAnimationController;

  /// Tracks if the refresh button was clicked to control animation state
  bool _isRefreshButtonClicked = false;

  /// Instance of RecentBillsManager for managing bill data
  final _billsManager = RecentBillsManager();

  @override
  void initState() {
    super.initState();

    // Initialize the refresh button rotation animation controller
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 745),
    );

    // Load bills from storage when the screen is first shown
    _loadBills();
  }

  @override
  void dispose() {
    // Clean up animation controller to prevent memory leaks
    _refreshAnimationController.dispose();
    super.dispose();
  }

  /// Loads bills from persistent storage
  ///
  /// This method retrieves the list of saved bills from the database,
  /// handling loading states and errors. It includes a small artificial
  /// delay to ensure the loading state is visible for better UX.
  Future<void> _loadBills() async {
    try {
      // Show loading state
      setState(() {
        _isLoading = true;
      });

      // Fetch bills from storage via the manager
      final bills = await _billsManager.getRecentBills();

      // Add a small delay to make the loading state visible
      // This improves perceived performance and reduces UI flashing
      await Future.delayed(const Duration(milliseconds: 800));

      // Update state if widget is still mounted
      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
          _isRefreshButtonClicked = false; // Reset refresh button state
        });

        // Reset refresh animation
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    } catch (e) {
      // Handle errors gracefully
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshButtonClicked = false; // Reset refresh button state
        });

        // Stop refresh animation
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();

        // Show error message to user
        _showErrorSnackBar('Failed to load recent bills');
      }
    }
  }

  /// Shows a confirmation dialog for deleting all bills
  ///
  /// This method displays a modal bottom sheet with information about
  /// the consequences of deleting all bills, requiring explicit confirmation
  /// to proceed with the deletion.
  void _showDeleteConfirmation() {
    // Provide tactile feedback when opening modal
    HapticFeedback.mediumImpact();

    // Get theme information for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white;

    // Warning colors - deeper red for dark mode, light red for light mode
    final warningColor =
        brightness == Brightness.dark
            ? Color(0xFF6D0D12) // Deeper red for dark mode
            : Color(0xFFFDECEE); // Light red background for light mode

    final warningTextColor =
        brightness == Brightness.dark
            ? Color(0xFFFF8282) // Lighter red text for dark mode
            : Color(0xFFB3261E); // Darker red text for light mode

    // Show the modal bottom sheet with animated entry
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 1.0, end: 0.0),
          builder: (context, value, child) {
            // Slide up animation
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
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle at the top
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Warning icon in a colored circle
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

                // Title text
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

                // Description text with bill count
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
                      // Cancel button (outline style)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            HapticFeedback.lightImpact(); // Subtle feedback
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

                      // Delete button (filled style with error color)
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            // Close modal
                            Navigator.of(context).pop();

                            // Strong haptic feedback for destructive action
                            HapticFeedback.heavyImpact();

                            // Show loading state
                            setState(() {
                              _isLoading = true;
                            });

                            // Delete all bills and reload the view
                            _billsManager.clearAllBills().then((_) {
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

                // Extra padding to account for bottom safe area on devices with notches
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows an error message as a snackbar
  ///
  /// This method displays a themed error message with an icon
  /// and provides haptic feedback to alert the user.
  ///
  /// Parameters:
  /// - message: The error message to display
  void _showErrorSnackBar(String message) {
    // Provide strong haptic feedback for errors
    HapticFeedback.vibrate();

    // Apply theme-aware styling
    final brightness = Theme.of(context).brightness;
    final snackBarBgColor =
        brightness == Brightness.dark
            ? const Color(0xFF3A0D0D) // Darker red for dark mode
            : Theme.of(context).colorScheme.error;

    final snackBarTextColor = Colors.white;

    // Show the snackbar with error styling
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
        behavior: SnackBarBehavior.floating, // Float above content
        width: MediaQuery.of(context).size.width * 0.9, // Responsive width
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: snackBarBgColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors
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
            HapticFeedback.selectionClick(); // Tactile feedback
            Navigator.pop(context);
          },
        ),
        actions: [
          // Delete all button
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            color: colorScheme.error,
            onPressed: () {
              // Only enable if not currently loading and bills exist
              if (!_isRefreshButtonClicked &&
                  !_isLoading &&
                  _bills.isNotEmpty) {
                HapticFeedback.selectionClick(); // Tactile feedback
                _showDeleteConfirmation();
              }
            },
          ),

          // Refresh button with rotation animation
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshAnimationController,
              builder: (context, child) {
                // Only show rotation animation when refresh is in progress
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
              // Only enable if not already refreshing
              if (!_isRefreshButtonClicked && !_isLoading) {
                HapticFeedback.selectionClick(); // Tactile feedback

                // Update state to show animation
                setState(() {
                  _isRefreshButtonClicked = true;
                });

                // Start rotation animation
                _refreshAnimationController.reset();
                _refreshAnimationController.repeat();

                // Reload bills
                _loadBills();
              }
            },
          ),
        ],
      ),
      // Main content with pull-to-refresh support
      body: RefreshIndicator(
        onRefresh: _loadBills,
        color: colorScheme.primary,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Enable overscroll for refresh
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Always show the header regardless of bill count
            _buildListHeader(
              headerTextColor,
              headerSecondaryTextColor,
              headerIconBgColor,
              colorScheme,
            ),

            // Content area - show appropriate state based on loading and bill count
            if (_isLoading)
              const LoadingBillsState() // Loading placeholder
            else if (_bills.isEmpty)
              const EmptyBillsState() // Empty state with CTA
            else
              _buildBillsList(), // List of bill cards
          ],
        ),
      ),
    );
  }

  /// Builds the header with bill count and information
  ///
  /// This method creates a visually appealing header card that displays
  /// the bill count and helpful information about bill storage limits.
  ///
  /// Parameters:
  /// - headerTextColor: Color for primary text
  /// - headerSecondaryTextColor: Color for secondary text
  /// - headerIconBgColor: Background color for the icon container
  /// - colorScheme: The current theme's color scheme
  Widget _buildListHeader(
    Color headerTextColor,
    Color headerSecondaryTextColor,
    Color headerIconBgColor,
    ColorScheme colorScheme,
  ) {
    final brightness = Theme.of(context).brightness;

    // Shadow color with different opacity based on theme
    final shadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(
              alpha: 0.5,
            ) // More visible in dark mode
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
          // Bill count badge (or loading indicator)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: headerIconBgColor,
              shape: BoxShape.circle,
            ),
            child:
                _isLoading
                    ? _buildAnimatedDots(
                      headerTextColor,
                    ) // Show dots when loading
                    : Text(
                      '${_bills.length}', // Show actual count when loaded
                      style: TextStyle(
                        color: headerTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
          ),

          const SizedBox(width: 12),

          // Header text content
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

  /// Creates the animated loading dots indicator
  ///
  /// This method returns a widget with animated dots for the loading state,
  /// providing visual feedback during data retrieval.
  ///
  /// Parameters:
  /// - dotColor: The color for the animated dots
  Widget _buildAnimatedDots(Color dotColor) {
    return SizedBox(
      width: 24,
      height: 20,
      child: Center(
        child: LoadingDots(color: dotColor, size: 4.0, spacing: 3.0),
      ),
    );
  }

  /// Handles deleting a bill or refreshing a specific bill
  ///
  /// This method can be used in two ways:
  /// 1. When billId >= 0, it deletes that specific bill
  /// 2. When billId is -1, it acts as a refresh for the entire list
  ///
  /// This dual-purpose approach allows for a smooth UX with quick updates.
  Future<void> _handleBillDeleted(int billId) async {
    // If billId is -1, we're just doing a refresh, not a delete
    if (billId == -1) {
      // Just reload the bills without showing loading state
      final bills = await _billsManager.getRecentBills();
      if (mounted) {
        setState(() {
          _bills = bills;
        });
      }
      return;
    }

    // Otherwise, delete the bill from storage
    await _billsManager.deleteBill(billId);

    // Update local state by removing the deleted bill
    if (mounted) {
      setState(() {
        _bills.removeWhere((bill) => bill.id == billId);
      });
    }
  }

  /// Builds the list of bill cards
  ///
  /// This method sorts bills by date (newest first) and creates
  /// a card for each bill with appropriate callbacks.
  Widget _buildBillsList() {
    // Sort bills by date (newest first)
    final sortedBills = List<RecentBillModel>.from(_bills)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Create a card for each bill with the onDeleted callback that
    // updates state without a full reload for better UX
    return Column(
      children:
          sortedBills
              .map(
                (bill) => RecentBillCard(
                  bill: bill,
                  onDeleted: () => _handleBillDeleted(bill.id),
                  onRefreshNeeded:
                      () => _handleBillDeleted(-1), // Special refresh signal
                ),
              )
              .toList(),
    );
  }
}
