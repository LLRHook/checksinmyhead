import 'package:checks_frontend/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'tutorial_overlay.dart';

/// Manages the tutorial state and functionality for item assignment screen
class TutorialManager {
  // Flag to track if user has seen the tutorial
  bool _hasSeenTutorial = false;

  // Preference key for storing tutorial state
  static const String _tutorialPreferenceKey =
      'has_seen_item_assignment_tutorial';

  // Tutorial steps for item assignment screen with enhanced descriptions
  final List<TutorialStep> tutorialSteps = [
    const TutorialStep(
      title: 'Expand Items!',
      description: 'Tap any dish to see its magical splitting options!',
      icon: Icons.touch_app,
    ),
    const TutorialStep(
      title: 'One-Tap Magic',
      description:
          'Tap a friend\'s avatar to instantly assign the whole item. Color-coding makes tracking a breeze!',
      icon: Icons.person_outline,
    ),
    const TutorialStep(
      title: 'Share the Love',
      description:
          'Hit "Multi-Split" to divide an item among multiple hungry friends. Perfect for those shared nachos!',
      icon: Icons.groups_outlined,
    ),
    const TutorialStep(
      title: 'Precision Mode',
      description:
          'Drag sliders within multi-split to set exact percentages, allowing more precise splits!',
      icon: Icons.pie_chart,
    ),
    const TutorialStep(
      title: 'Birthday Surprise',
      description:
          'Hold down on an avatar to mark them as the birthday star! Their costs vanish and everyone else picks up the tab.',
      icon: Icons.cake,
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

  /// Load tutorial state from database
  Future<void> _loadTutorialState() async {
    try {
      _hasSeenTutorial = await DatabaseProvider.db.hasTutorialBeenSeen(
        _tutorialPreferenceKey,
      );
    } catch (e) {
      print('Error loading tutorial state: $e');
      _hasSeenTutorial = false;
    }
  }

  /// Save tutorial state to database
  Future<bool> saveTutorialState() async {
    try {
      await DatabaseProvider.db.markTutorialAsSeen(_tutorialPreferenceKey);
      _hasSeenTutorial = true;
      return true;
    } catch (e) {
      print('Error saving tutorial state: $e');
      return false;
    }
  }

  /// Show the tutorial overlay and save state
  Future<void> showTutorial(BuildContext context) async {
    // Save state first and wait for it to complete
    await saveTutorialState();

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

  /// Reset the tutorial state (useful for testing)
  Future<void> resetTutorial() async {
    try {
      await DatabaseProvider.db.resetTutorial(_tutorialPreferenceKey);
      _hasSeenTutorial = false;
    } catch (e) {
      print('Error resetting tutorial: $e');
    }
  }
}
