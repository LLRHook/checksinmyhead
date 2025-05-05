// Purpose: Serves as the main entry point/home screen for the Checkmate bill-splitting app.
// This screen provides navigation to core app features with an animated interface.
//
// Features:
// - Quick Split: Opens participant selection for bill splitting
// - Recent Bills: Shows history of previous bill splits
// - Settings: Access to app configuration options
//
// Animations:
// - Uses fade-in animations for a smooth user experience
//
import 'package:checks_frontend/screens/recent_bills/recent_bills_screen.dart';
import 'package:checks_frontend/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'quick_split/participant_selection/participant_selection_sheet.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller to handle all animations on the landing screen
  late AnimationController _animationController;

  // Animation for fading in the content
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller with 700ms duration
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this, // The SingleTickerProviderStateMixin provides vsync
    );

    // Create a fade-in animation that eases out
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start the animation immediately when screen loads
    _animationController.forward();
  }

  @override
  void dispose() {
    // Clean up animation controller to prevent memory leaks
    _animationController.dispose();
    super.dispose();
  }

  /// Opens the bottom sheet for selecting participants in a bill split
  void _showQuickSplitSheet() {
    showParticipantSelectionSheet(context);
  }

  /// Navigates to the screen showing history of recent bills
  void _navigateToRecentBills() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecentBillsScreen()),
    );
  }

  /// Navigates to the app settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the app's color scheme for consistent styling
    final colorScheme = Theme.of(context).colorScheme;

    // Get screen dimensions to create responsive layout
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Transparent app bar blends with background
        elevation: 0, // Remove shadow
        automaticallyImplyLeading: false, // Don't show back button
        actions: [
          // Settings button in top-right corner
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 26),
              onPressed: _navigateToSettings,
              tooltip: 'Settings', // Accessibility feature
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Top spacing - reduced because we have an app bar
              SizedBox(height: size.height * 0.08),

              // Main content area with action buttons
              Expanded(
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Primary button: Quick Split with calculator icon
                        ElevatedButton(
                          onPressed: _showQuickSplitSheet,
                          style: ElevatedButton.styleFrom(
                            // Semi-transparent white background
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0, // Flat button with no shadow
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calculate, size: 22),
                              const SizedBox(width: 10),
                              const Text(
                                'Quick Split',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Secondary button: Recent Bills with history icon
                        TextButton(
                          onPressed: _navigateToRecentBills,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Bills',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer with logo and copyright - animated to fade in with content
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: size.height * 0.05),
                    child: Opacity(
                      opacity: _fadeInAnimation.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Row(
                                children: [
                                  // App logo icon
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 20,
                                    color: Colors.white.withAlpha(180),
                                  ),

                                  const SizedBox(width: 8),

                                  // App name with SF Pro Display font for iOS-like appearance
                                  Text(
                                    'Checkmate',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(180),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.37,
                                      fontFamily: '.SF Pro Display',
                                    ),
                                  ),
                                ],
                              ),
                              // Copyright text with slightly reduced opacity
                              Text(
                                '© 2025 Kruski Ko.',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(140),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
