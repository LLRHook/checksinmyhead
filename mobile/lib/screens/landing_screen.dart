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
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Fade in animation for content
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Show participant selection sheet when quick split button is pressed
  void _showQuickSplitSheet() {
    // Use the imported function with the updated name
    showParticipantSelectionSheet(context);
  }

  // Navigate to Recent Bills screen
  void _navigateToRecentBills() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecentBillsScreen()),
    );
  }

  // Navigate to Settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      // Add AppBar with settings icon
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Settings cog button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 26),
              onPressed: _navigateToSettings,
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Reduced space at top since we now have an app bar
              SizedBox(height: size.height * 0.08),

              // Action buttons take center stage
              Expanded(
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick Split Button
                        ElevatedButton(
                          onPressed: _showQuickSplitSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
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

                        // Recent Bills Button
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
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 20,
                                    color: Colors.white.withAlpha(180),
                                  ),

                                  const SizedBox(width: 8),

                                  // App name
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
