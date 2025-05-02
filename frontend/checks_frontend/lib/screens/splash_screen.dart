import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // In _SplashScreenState class
  @override
  void initState() {
    super.initState();

    // Create animation controller with shorter duration
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    // Entrance animations (initial 60% of time)
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Exit animations (final 30% of time)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start entrance animation
    _controller.forward(from: 0.0);

    // Check if it's the first launch
    _checkFirstLaunch();
  }

  // Add this method to check first launch
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    // Wait before starting exit animation - shorter duration
    Timer(const Duration(milliseconds: 900), () {
      setState(() {
        _startExitAnimation = true;
      });

      // Continue animation to include exit sequence - shorter duration
      Timer(const Duration(milliseconds: 400), () {
        // Navigate to landing screen or settings based on first launch
        if (isFirstLaunch) {
          Navigator.of(context).pushReplacementNamed('/settings');
        } else {
          Navigator.of(context).pushReplacementNamed('/landing');
        }
      });
    });
  }

  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  // Additional animations for the exit transition
  late Animation<double> _fadeOutAnimation;
  late Animation<Offset> _slideOutAnimation;

  bool _startExitAnimation = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SlideTransition(
              position:
                  _startExitAnimation
                      ? _slideOutAnimation
                      : const AlwaysStoppedAnimation<Offset>(Offset.zero),
              child: FadeTransition(
                opacity:
                    _startExitAnimation ? _fadeOutAnimation : _fadeInAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Clean Apple-style icon (no background circle)
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 30),
                      // App name - using system font weight and size
                      Text(
                        'Checkmate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34, // Large display text in Apple's style
                          fontWeight:
                              FontWeight.w600, // Semibold in Apple's style
                          letterSpacing:
                              0.37, // Apple's tracking for large display
                          fontFamily:
                              '.SF Pro Display', // Using system font reference
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tagline - using Apple's secondary text style
                      Text(
                        'Smart Receipt Splitting',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 17, // Standard body text in Apple's apps
                          fontWeight: FontWeight.w400, // Regular weight
                          letterSpacing:
                              -0.41, // Apple's tracking for body text
                          fontFamily:
                              '.SF Pro Text', // Using system font reference
                        ),
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
