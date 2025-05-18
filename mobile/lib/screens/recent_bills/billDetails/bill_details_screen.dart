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

import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_name_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/components/participants_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/settings/services/settings_manager.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'utils/bill_calculations.dart';

/// BillDetailsScreen
///
/// A detailed view screen that displays comprehensive information about a saved bill.
/// This screen provides a polished UI with animations for viewing bill details,
/// participant breakdowns, and sharing options.
///
/// Features:
/// - Animated header with bill date and total amount
/// - Bill summary information (subtotal, tax, tip, etc.)
/// - Participant breakdown showing who owes what
/// - Share functionality with customizable sharing options
/// - Theme-aware styling that adapts to light/dark mode
///
/// The screen carefully manages loading states, animations, and preserves
/// user preferences for sharing options between sessions.
class BillDetailsScreen extends StatefulWidget {
  /// The bill model containing all bill data to display
  final RecentBillModel bill;

  const BillDetailsScreen({super.key, required this.bill});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  // Share options that persist between sessions
  late ShareOptions _shareOptions;

  // Loading state tracker for async initialization
  bool _isLoading = true;

  // Local copy of the bill to track updates
  late RecentBillModel _bill;

  // Track if the bill name was updated
  bool _wasNameUpdated = false;

  // Instance of RecentBillsManager for managing bill data
  final _billsManager = RecentBillsManager();

  @override
  void initState() {
    super.initState();

    // Initialize with default share options until loaded from persistent storage
    _shareOptions = ShareOptions(
      showAllItems: true,
      showPersonItems: true,
      showBreakdown: true,
    );

    // Initialize local bill copy
    _bill = widget.bill;

    // Load user's previously saved share options
    _loadShareOptions();
  }

  /// Shows the bottom sheet for editing bill name
  ///
  /// This method displays a modal bottom sheet allowing the user to
  /// edit the bill name and save changes to the database.
  Future<bool> _showBillNameEditSheet(
    String currentName,
    Function(String) onNameUpdated,
  ) async {
    final newName = await BillNameSheet.show(
      context: context,
      initialName: currentName,
    );

    // Check if name was changed and not empty
    if (newName.isNotEmpty && newName != currentName) {
      // Provide haptic feedback for successful update
      HapticFeedback.lightImpact();

      // Call the callback to update the name
      onNameUpdated(newName);
      return true;
    }

    return false;
  }

  /// Loads share options from persistent storage
  ///
  /// This method retrieves the user's previously saved share preferences.
  /// If loading fails, it silently keeps using the default options to ensure
  /// the app can continue functioning.
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
      // If there's an error loading options, use default values and continue
      // This ensures the app doesn't crash if settings can't be loaded
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // We'll handle the navigation in the back button instead of dispose()
  @override
  void dispose() {
    super.dispose();
  }

  /// Shows the share options bottom sheet
  ///
  /// This method displays a modal bottom sheet allowing the user to
  /// customize their sharing preferences before sharing the bill.
  void _promptShareOptions() {
    ShareOptionsSheet.show(
      context: context,
      initialOptions: _shareOptions,
      onOptionsChanged: (updatedOptions) {
        setState(() {
          _shareOptions = updatedOptions;
        });
        // Save updated options to database for future use
        SettingsManager.saveShareOptions(updatedOptions);
      },
      onShareTap: _shareBillSummary,
    );
  }

  /// Shares the bill summary using the configured options
  ///
  /// This method prepares and formats the bill data according to the user's
  /// sharing preferences, then triggers the system share sheet.
  Future<void> _shareBillSummary() async {
    // Use the BillCalculations utility to prepare data
    final billCalculations = BillCalculations(_bill);

    // Convert the saved bill data back to the format needed for sharing
    final String summary = await ShareUtils.generateShareText(
      participants:
          _bill.participantNames
              .map((name) => Person(name: name, color: _bill.color))
              .toList(),
      personShares: billCalculations.generatePersonShares(),
      items: billCalculations.generateBillItems(),
      subtotal: _bill.subtotal,
      tax: _bill.tax,
      tipAmount: _bill.tipAmount,
      total: _bill.total,
      birthdayPerson:
          null, // Assuming birthday person isn't stored in recent bills
      tipPercentage: _bill.tipPercentage,
      isCustomTipAmount: false, // Assuming this isn't stored
      includeItemsInShare: _shareOptions.showAllItems,
      includePersonItemsInShare: _shareOptions.showPersonItems,
      hideBreakdownInShare: !_shareOptions.showBreakdown,
      billName: _bill.billName,
    );

    // Invoke the system share sheet with the formatted summary
    ShareUtils.shareBillSummary(summary: summary);
  }

  @override
  Widget build(BuildContext context) {
    // Get theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors for consistent appearance in both modes
    final scaffoldBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50];

    final loadingIndicatorColor = colorScheme.primary;

    final appBarIconColor = colorScheme.onSurface;

    final titleColor = colorScheme.onSurface;

    // Header shadow - more visible in dark mode for better depth perception
    final headerShadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .4)
            : colorScheme.primary.withValues(alpha: .2);

    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBgColor,
        body: Center(
          child: CircularProgressIndicator(color: loadingIndicatorColor),
        ),
      );
    }

    // Create a single instance of BillCalculations for all child widgets
    // This avoids redundant calculations across different components
    final billCalculations = BillCalculations(_bill);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with back button and title
            _buildAppBar(context, appBarIconColor, titleColor, scaffoldBgColor),

            // Main scrollable content area
            Expanded(
              child: ListView(
                physics:
                    const BouncingScrollPhysics(), // Bouncy scroll for iOS-like feel
                padding: EdgeInsets.zero,
                children: [
                  // Animated premium header with bill date and total
                  _buildPremiumHeader(context, headerShadowColor, (
                    newName,
                  ) async {
                    // Update bill name in database
                    await _billsManager.updateBillName(_bill.id, newName);

                    // Update local state
                    if (mounted) {
                      setState(() {
                        // Create a new bill model with updated name
                        _bill = RecentBillModel(
                          id: _bill.id,
                          billName: newName,
                          participantNames: _bill.participantNames,
                          participantCount: _bill.participantCount,
                          total: _bill.total,
                          date: _bill.date,
                          subtotal: _bill.subtotal,
                          tax: _bill.tax,
                          tipAmount: _bill.tipAmount,
                          tipPercentage: _bill.tipPercentage,
                          items: _bill.items,
                          color: _bill.color,
                          itemAssignments: _bill.itemAssignments,
                        );

                        // Mark that bill name was updated to notify previous screen
                        _wasNameUpdated = true;
                      });
                    }
                  }),

                  // Main content section with cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      80,
                    ), // Extra bottom padding for FAB
                    child: Column(
                      children: [
                        // Combined Bill Details card with fade-in and slide-up animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  10 * (1 - value),
                                ), // Slide up as opacity increases
                                child: child,
                              ),
                            );
                          },
                          child: CombinedBillDetailsCard(
                            bill: _bill,
                            calculations: billCalculations,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Participants card with staggered animation (starts after bill summary)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            // Delay the start for staggered effect
                            final delayedValue =
                                (value - 0.3).clamp(0.0, 1.0) * 1.4;
                            return Opacity(
                              opacity: delayedValue,
                              child: Transform.translate(
                                offset: Offset(0, 15 * (1 - delayedValue)),
                                child: child,
                              ),
                            );
                          },
                          child: SortedParticipantsCard(
                            bill: _bill,
                            calculations:
                                billCalculations, // Pass the calculations instance
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Bottom Action Bar with slide-up animation
      bottomNavigationBar: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          // Even more delayed start for staggered sequence
          final delayedValue = (value - 0.3).clamp(0.0, 1.0) * 1.4;
          return Transform.translate(
            offset: Offset(0, 20 * (1 - delayedValue)), // Slide up effect
            child: Opacity(opacity: delayedValue, child: child),
          );
        },
        // Use a custom bottom bar with share functionality
        child: _buildCustomBottomBar(context),
      ),
    );
  }

  /// Builds the custom bottom bar with share button
  ///
  /// This method creates a theme-aware bottom bar that contains
  /// the share button, which opens the share options sheet.
  Widget _buildCustomBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for the bottom bar
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Subtle shadow - less intense in dark mode
    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .03);

    // Outline button colors - slightly transparent in dark mode for softer appearance
    final outlineColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .8)
            : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(0, -2), // Shadow above the bar
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Share button spanning the full width
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _promptShareOptions, // Opens the options sheet
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: outlineColor,
                  side: BorderSide(color: outlineColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the custom app bar with back button and title
  ///
  /// This method creates an app bar with animated elements and
  /// haptic feedback for better user experience.
  Widget _buildAppBar(
    BuildContext context,
    Color iconColor,
    Color titleColor,
    Color? bgColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          // Back button with scale animation and haptic feedback
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value), // Scale from 80% to 100%
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Add haptic feedback for better tactile response
                  HapticFeedback.selectionClick();
                  if (mounted) {
                    // Return whether the bill name was updated
                    Navigator.pop(context, _wasNameUpdated);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(), // Push title to center
          // Title with fade-in and slide-up animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    10 * (1 - value),
                  ), // Slide up as opacity increases
                  child: child,
                ),
              );
            },
            child: Text(
              'Bill Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),

          const Spacer(), // Balance layout for centered title
        ],
      ),
    );
  }

  /// Builds the premium header with gradient background and animations
  ///
  /// This method creates an eye-catching header that displays the bill name, date,
  /// and total amount with various animations for a premium feel.
  Widget _buildPremiumHeader(
    BuildContext context,
    Color shadowColor,
    Function(String) onNameUpdated,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Gradient colors - subtle difference in dark mode for better visibility
    final gradientStartColor = colorScheme.primary;
    final gradientEndColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(
              alpha: 0.9,
            ) // Less contrast in dark mode
            : colorScheme.primary.withValues(alpha: .85);

    // Wrap the header in an animated container with scale and fade effects
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value), // Subtle scaling from 95% to 100%
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // Diagonal gradient for visual interest
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientStartColor, gradientEndColor],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bill name and date with shimmer effect
            ShimmerEffect(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showBillNameEditSheet(_bill.billName, onNameUpdated);
                },
                child: Column(
                  children: [
                    // Combined name and date section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Name display or prompt
                        Flexible(
                          child: Text(
                            _bill.billName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit, color: Colors.white, size: 16),
                      ],
                    ),

                    // Date display always shown below the name
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _bill.formattedDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Total amount with bounce scale animation for emphasis
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut, // Bouncy effect for emphasis
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Text(
                CurrencyFormatter.formatCurrency(_bill.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  letterSpacing: 0.5, // Slight spacing for better readability
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ShimmerEffect
///
/// A widget that applies a subtle pulsing opacity animation to its child,
/// creating a premium "shimmer" effect that draws attention.
///
/// This effect is used for enhancing UI elements that should stand out,
/// such as dates, prices, or other important information.
class ShimmerEffect extends StatefulWidget {
  /// The widget to which the shimmer effect will be applied
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  // Animation controller for the shimmer effect
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Create controller with slow pulsing speed (1.5 seconds)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true); // Auto-repeat with reverse for smooth pulsing

    // Create animation that subtly changes opacity from 80% to 100%
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    // Properly dispose of the animation controller to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apply the animated opacity to the child widget
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(opacity: _animation.value, child: widget.child);
      },
    );
  }
}

/// CombinedBillDetailsCard
///
/// A single card that combines bill items and breakdown sections
class CombinedBillDetailsCard extends StatelessWidget {
  final RecentBillModel bill;
  final BillCalculations calculations;

  const CombinedBillDetailsCard({
    super.key,
    required this.bill,
    required this.calculations,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .3)
            : Colors.grey.shade200;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .2)
            : Colors.grey.shade200;

    final tipBadgeBgColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .2)
            : colorScheme.primary.withValues(alpha: .1);

    final textColor = colorScheme.onSurface;

    return Card(
      elevation: 1,
      surfaceTintColor: cardBgColor,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        children: [
          // Items Section
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: cardBgColor,
              collapsedBackgroundColor: cardBgColor,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              initiallyExpanded: true,
              onExpansionChanged: (expanded) {
                HapticFeedback.lightImpact();
              },
              title: Row(
                children: [
                  Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${bill.items?.length ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: Column(
                    children:
                        bill.items?.map((item) {
                          final name =
                              item['name'] as String? ?? 'Unknown Item';
                          final price =
                              (item['price'] as num?)?.toDouble() ?? 0.0;

                          return _buildItemRow(
                            context,
                            name,
                            price,
                            colorScheme,
                          );
                        }).toList() ??
                        [],
                  ),
                ),
              ],
            ),
          ),

          // Divider between sections
          Divider(height: 1, color: dividerColor),

          // Breakdown Section
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: cardBgColor,
              collapsedBackgroundColor: cardBgColor,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              initiallyExpanded: true,
              onExpansionChanged: (expanded) {
                HapticFeedback.lightImpact();
              },
              title: Row(
                children: [
                  Text(
                    'Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: Column(
                    children: [
                      // Subtotal row
                      _buildDetailRow(
                        context,
                        'Subtotal',
                        bill.subtotal,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),

                      // Tax row
                      _buildDetailRow(
                        context,
                        'Tax',
                        bill.tax,
                        textColor: textColor,
                      ),

                      // Tip row - only shown if tip amount is greater than zero
                      if (bill.tipAmount > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tip', style: TextStyle(color: textColor)),
                            Row(
                              children: [
                                // Tip amount in currency format
                                Text(
                                  CurrencyFormatter.formatCurrency(
                                    bill.tipAmount,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Tip percentage badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tipBadgeBgColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${bill.tipPercentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildItemRow(
    BuildContext context,
    String name,
    double price,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
          ),
          Text(
            CurrencyFormatter.formatCurrency(price),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    double value, {
    bool isTotal = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: textColor,
          ),
        ),
        Text(
          CurrencyFormatter.formatCurrency(value),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 14,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// SortedParticipantsCard
///
/// A wrapper around ParticipantsCard that sorts participants by amount owed in descending order
class SortedParticipantsCard extends StatelessWidget {
  final RecentBillModel bill;
  final BillCalculations calculations;

  const SortedParticipantsCard({
    super.key,
    required this.bill,
    required this.calculations,
  });

  @override
  Widget build(BuildContext context) {
    // Get pre-calculated person totals from the BillCalculations utility
    final personTotals = calculations.calculatePersonTotals();

    // Check if bill has custom item assignments or uses equal splitting
    final hasRealAssignments = calculations.hasRealAssignments();
    final equalShare = calculations.calculateEqualShare();

    // Create a sorted list of participants based on their total amounts
    final sortedParticipants = List<String>.from(bill.participantNames);
    sortedParticipants.sort((a, b) {
      final amountA =
          hasRealAssignments ? (personTotals[a] ?? 0.0) : equalShare;
      final amountB =
          hasRealAssignments ? (personTotals[b] ?? 0.0) : equalShare;
      return amountB.compareTo(amountA); // Descending order
    });

    // Create a new bill with sorted participants
    final sortedBill = RecentBillModel(
      id: bill.id,
      billName: bill.billName,
      participantNames: sortedParticipants,
      participantCount: bill.participantCount,
      total: bill.total,
      date: bill.date,
      subtotal: bill.subtotal,
      tax: bill.tax,
      tipAmount: bill.tipAmount,
      tipPercentage: bill.tipPercentage,
      items: bill.items,
      color: bill.color,
      itemAssignments: bill.itemAssignments,
    );

    return ParticipantsCard(bill: sortedBill, calculations: calculations);
  }
}
