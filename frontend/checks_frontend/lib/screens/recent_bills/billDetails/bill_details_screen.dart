import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:checks_frontend/screens/recent_bills/components/bill_summary_card.dart';
import 'package:checks_frontend/screens/recent_bills/components/bottom_bar.dart';
import 'package:checks_frontend/screens/recent_bills/components/participants_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/utils/settings_manager.dart';
import 'package:checks_frontend/models/person.dart';

// Local imports
import 'utils/bill_calculations.dart';

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

    // Share the summary
    ShareUtils.shareBillSummary(context: context, summary: summary);
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

    final loadingIndicatorColor = colorScheme.primary;

    final appBarIconColor = colorScheme.onSurface;

    final titleColor = colorScheme.onSurface;

    // Header shadow color
    final headerShadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.4) // More visible in dark mode
            : colorScheme.primary.withOpacity(0.2);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBgColor,
        body: Center(
          child: CircularProgressIndicator(color: loadingIndicatorColor),
        ),
      );
    }

    // Create a single instance of BillCalculations for all child widgets
    final billCalculations = BillCalculations(widget.bill);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // App bar with back and share buttons
            _buildAppBar(context, appBarIconColor, titleColor),

            // Expanded content with scrollable cards
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // Premium animated header (non-sticky)
                  _buildPremiumHeader(context, headerShadowColor),

                  // Content with padding
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Column(
                      children: [
                        // Bill details card with fade-in animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: BillSummaryCard(bill: widget.bill),
                        ),

                        const SizedBox(height: 16),

                        // Participants card with staggered animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            // Delayed start for staggered effect
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
                            calculations: billCalculations,
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
      // Bottom Action Bar with slide-up animation (inside BillDetailsScreen)
      bottomNavigationBar: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final delayedValue = (value - 0.3).clamp(0.0, 1.0) * 1.4;
          return Transform.translate(
            offset: Offset(0, 20 * (1 - delayedValue)),
            child: Opacity(opacity: delayedValue, child: child),
          );
        },
        child: BottomBar(
          onShareTap: _promptShareOptions,
          bill: widget.bill, // Pass the bill here
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color iconColor, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          // Back button with micro-interaction
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Add a subtle ripple effect before navigating back
                  HapticFeedback.selectionClick();

                  // Create a small delay for better tactile feedback
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

          const Spacer(),

          // Title with fade-in animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
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

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, Color shadowColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Adjust gradient for better visibility in dark mode
    final gradientStartColor = colorScheme.primary;
    final gradientEndColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(
              0.9,
            ) // Less opacity difference in dark mode
            : colorScheme.primary.withOpacity(0.85);

    // Wrap the header in an animated container
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
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
            // Date row with subtle shimmer
            ShimmerEffect(
              child: Row(
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
            ),
            const SizedBox(height: 12),

            // Total amount with scale animation
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Text(
                CurrencyFormatter.formatCurrency(widget.bill.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A subtle shimmer effect for premium feel
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({Key? key, required this.child}) : super(key: key);

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(opacity: _animation.value, child: widget.child);
      },
    );
  }
}
