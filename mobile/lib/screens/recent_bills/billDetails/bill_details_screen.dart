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
import 'package:checks_frontend/screens/recent_bills/components/bill_summary_card.dart';
import 'package:checks_frontend/screens/recent_bills/components/participants_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/settings/services/settings_manager.dart';
import 'package:checks_frontend/models/person.dart';
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

  @override
  void initState() {
    super.initState();

    // Initialize with default share options until loaded from persistent storage
    _shareOptions = ShareOptions(
      includeItemsInShare: true,
      includePersonItemsInShare: true,
      hideBreakdownInShare: false,
    );

    // Load user's previously saved share options
    _loadShareOptions();
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
    final billCalculations = BillCalculations(widget.bill);

    // Convert the saved bill data back to the format needed for sharing
    final String summary = await ShareUtils.generateShareText(
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
    final billCalculations = BillCalculations(widget.bill);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with back button and title
            _buildAppBar(context, appBarIconColor, titleColor),

            // Main scrollable content area
            Expanded(
              child: ListView(
                physics:
                    const BouncingScrollPhysics(), // Bouncy scroll for iOS-like feel
                padding: EdgeInsets.zero,
                children: [
                  // Animated premium header with bill date and total
                  _buildPremiumHeader(context, headerShadowColor),

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
                        // Bill summary card with fade-in and slide-up animation
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
                          child: BillSummaryCard(bill: widget.bill),
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
                                (value - 0.2).clamp(0.0, 1.0) * 1.25;
                            return Opacity(
                              opacity: delayedValue,
                              child: Transform.translate(
                                offset: Offset(0, 15 * (1 - delayedValue)),
                                child: child,
                              ),
                            );
                          },
                          child: ParticipantsCard(
                            bill: widget.bill,
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
  Widget _buildAppBar(BuildContext context, Color iconColor, Color titleColor) {
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

                  // Small delay to let the ripple animation show before navigating
                  Future.delayed(const Duration(milliseconds: 50), () {
                    Navigator.pop(context);
                  });
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
  /// This method creates an eye-catching header that displays the bill date
  /// and total amount with various animations for a premium feel.
  Widget _buildPremiumHeader(BuildContext context, Color shadowColor) {
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
            // Date row with subtle shimmer effect for premium feel
            ShimmerEffect(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.white.withValues(alpha: .9),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget
                        .bill
                        .formattedDate, // Display formatted date from bill model
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
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
                CurrencyFormatter.formatCurrency(widget.bill.total),
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
