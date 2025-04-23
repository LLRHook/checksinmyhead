import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_overlay.dart';

/// Manages the tutorial state and functionality for item assignment screen
class TutorialManager {
  // Flag to track if user has seen the tutorial
  bool _hasSeenTutorial = false;

  // Preference key for storing tutorial state
  static const String _tutorialPreferenceKey =
      'has_seen_item_assignment_tutorial';

  // Tutorial steps for item assignment screen
  final List<TutorialStep> tutorialSteps = [
    const TutorialStep(
      title: 'Select a Person',
      description:
          'Tap an avatar to select someone. A checkmark appears when selected.',
      icon: Icons.person_outline,
    ),
    const TutorialStep(
      title: 'Assign Items',
      description:
          'With someone selected, tap "Assign to [Name]" on any item. Items take on that person\'s color.',
      icon: Icons.assignment_ind,
    ),
    const TutorialStep(
      title: 'Split Items',
      description:
          'Use "Split Evenly" for equal shares or "Custom Split" for precise control.',
      icon: Icons.splitscreen,
    ),
    const TutorialStep(
      title: 'Birthday Person',
      description:
          'Long-press any avatar to mark as birthday person. Their share gets split among others.',
      icon: Icons.cake,
    ),
    const TutorialStep(
      title: 'Review & Finish',
      description:
          'After assigning all items, tap Continue to see the final breakdown.',
      icon: Icons.check_circle_outline,
    ),
  ];

  // Private constructor
  TutorialManager._();

  // Factory method to create and initialize the manager
  static Future<TutorialManager> create() async {
    final manager = TutorialManager._();
    await manager._loadTutorialState();
    return manager;
  }

  /// Get whether the user has seen the tutorial
  bool get hasSeenTutorial => _hasSeenTutorial;

  /// Load tutorial state from SharedPreferences
  Future<void> _loadTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenTutorial = prefs.getBool(_tutorialPreferenceKey) ?? false;
  }

  /// Save tutorial state to SharedPreferences
  Future<bool> saveTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    final result = await prefs.setBool(_tutorialPreferenceKey, true);
    if (result) {
      _hasSeenTutorial = true;
    }
    return result;
  }

  /// Show the tutorial overlay and save state
  Future<void> showTutorial(BuildContext context) async {
    // Save state first and wait for it to complete
    final saved = await saveTutorialState();

    // Only show tutorial if context is still valid
    if (context.mounted) {
      showTutorialOverlay(context, steps: tutorialSteps);
    }
  }

  /// Initialize the tutorial on first launch
  void initializeWithDelay(BuildContext context, bool mounted) {
    if (!_hasSeenTutorial) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) showTutorial(context);
      });
    }
  }

  /// Create a tutorial button widget
  Widget buildTutorialButton(VoidCallback onPressed) {
    return TutorialButton(
      onPressed: onPressed,
      badge:
          !_hasSeenTutorial
              ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
              : null,
    );
  }
}
