// Billington: Privacy-first receipt splitting
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

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'landing_screen.dart';
import 'settings/settings_screen.dart';

/// A custom page route that provides a smooth fade transition between screens
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;

  FadePageRoute({required this.builder})
    : super(
        pageBuilder:
            (context, animation, secondaryAnimation) => builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Define curves for more premium feeling animations
          const fadeInCurve = Curves.easeOutCubic;
          const scaleCurve = Curves.easeOutQuint;

          var fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: fadeInCurve,
          );

          // Add a subtle scale transition for premium feel
          var scaleAnimation = Tween<double>(
            begin: 1.04, // Start slightly larger
            end: 1.0, // End at normal size
          ).animate(CurvedAnimation(parent: animation, curve: scaleCurve));

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
}

// Purpose: Provides an animated intro screen displayed when the app launches.
// This screen shows the app logo and name with smooth animations before
// navigating to either the onboarding (first launch) or landing screen.
//
// Features:
// - Multi-phase animations (fade-in, scale, fade-out, slide-out)
// - First-launch detection for onboarding flow
// - Automatic navigation after animation completes
// Navigation flow:
// - If first app launch: Redirects to Settings screen for onboarding
// - If returning user: Redirects to Landing screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for coordinating all animations
  late AnimationController _controller;

  // Entrance animations
  late Animation<double> _fadeInAnimation; // Controls opacity from 0 to 1
  late Animation<double>
  _scaleAnimation; // Controls slight scale up from 95% to 100%

  // Exit animations
  late Animation<double>
  _fadeOutAnimation; // Controls fade out (opacity 1 to 0)
  late Animation<Offset> _slideOutAnimation; // Controls upward slide out

  // Flag to trigger exit animations
  bool _startExitAnimation = false;

  // Timers for animation control
  Timer? _exitAnimationTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Create animation controller with 1300ms total animation duration
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this, // The SingleTickerProviderStateMixin provides vsync
    );

    // Fade in during first half of animation (0-50%)
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Scale up slightly during first half with a bouncy finish
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Fade out during last 30% of animation (70-100%)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Slide upward during last 30% of animation (70-100%)
    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.0), // Move upward by 100% of screen height
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start the animation sequence immediately
    _controller.forward(from: 0.0);

    // Check if this is first app launch and prepare navigation
    _checkFirstLaunch();
  }

  /// Determines if this is the first app launch to handle navigation flow.
  /// - First launch: Routes to Settings screen for onboarding
  /// - Subsequent launches: Routes directly to Landing screen
  Future<void> _checkFirstLaunch() async {
    // Get shared preferences instance to read/write app state
    final prefs = await SharedPreferences.getInstance();

    // Check if first launch flag exists, default to true if not found
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    // After 900ms, trigger exit animations
    _exitAnimationTimer = Timer(const Duration(milliseconds: 900), () {
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _startExitAnimation = true;
        });

        // After exit animation starts, wait 400ms before navigating
        _navigationTimer = Timer(const Duration(milliseconds: 400), () {
          // Check again if widget is still mounted before navigating
          if (mounted) {
            if (isFirstLaunch) {
              // First launch - go to settings/onboarding with fade transition
              Navigator.of(context).pushReplacement(
                FadePageRoute(
                  builder: (context) => SettingsScreen(isOnboarding: true),
                ),
              );
            } else {
              // Returning user - go directly to main landing screen with fade transition
              Navigator.of(context).pushReplacement(
                FadePageRoute(builder: (context) => const LandingScreen()),
              );
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Clean up animation controller to prevent memory leaks
    _controller.dispose();

    // Cancel timers to prevent memory leaks
    _exitAnimationTimer?.cancel();
    _navigationTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SlideTransition(
              // Use slide animation only when exit is triggered
              position:
                  _startExitAnimation
                      ? _slideOutAnimation
                      : const AlwaysStoppedAnimation<Offset>(Offset.zero),
              child: FadeTransition(
                // Switch between fade-in and fade-out animations based on exit state
                opacity:
                    _startExitAnimation ? _fadeOutAnimation : _fadeInAnimation,
                child: Transform.scale(
                  // Apply scaling animation
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo icon
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.85 + (0.15 * value),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.asset(
                                  'assets/images/spliqnobg.png',
                                  width: 160,
                                  height: 160,
                                ),
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
          },
        ),
      ),
    );
  }
}
