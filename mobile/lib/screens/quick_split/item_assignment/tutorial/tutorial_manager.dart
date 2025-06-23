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

import 'package:checks_frontend/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'tutorial_overlay.dart';

// A class that manages the tutorial state and functionality for the item assignment screen
class TutorialManager extends ChangeNotifier {
  // Flag to track if user has seen the tutorial
  bool _hasSeenTutorial = false;

  // Preference key for storing tutorial state in the database
  final String _tutorialPreferenceKey = 'has_seen_item_assignment_tutorial';

  // Tutorial steps for item assignment screen with enhanced descriptions
  final List<TutorialStep> tutorialSteps = [
    const TutorialStep(
      title: 'Expand Items',
      description: 'Tap any dish to see its splitting options!',
      icon: Icons.touch_app,
    ),
    const TutorialStep(
      title: 'One-Tap Magic',
      description: 'Tap a friend\'s avatar to instantly assign the whole item.',
      icon: Icons.person_outline,
    ),
    const TutorialStep(
      title: 'Share the Love',
      description:
          'Hit "Split Evenly" to share an item among everyone. Perfect for those shared nachos!',
      icon: Icons.groups_outlined,
    ),
    const TutorialStep(
      title: 'Precision Mode',
      description: '"Multi-Split" gives you the power for more precise splits!',
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
  // Returns a future that completes when the tutorial state is loaded
  static Future<TutorialManager> create() async {
    final manager = TutorialManager._();
    await manager._loadTutorialState();
    return manager;
  }

  // Singleton instance
  static TutorialManager? _instance;

  // Get or create an instance of TutorialManager
  static Future<TutorialManager> getInstance() async {
    _instance ??= await create();
    return _instance!;
  }

  // Reset the singleton instance (useful for testing or when you need a fresh instance)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  // Getter for whether the user has seen the tutorial
  bool get hasSeenTutorial => _hasSeenTutorial;

  // Loads the tutorial state from the database
  // Sets _hasSeenTutorial to false if there's an error
  Future<void> _loadTutorialState() async {
    try {
      _hasSeenTutorial = await DatabaseProvider.db.hasTutorialBeenSeen(
        _tutorialPreferenceKey,
      );
    } catch (e) {
      debugPrint('Error loading tutorial state: $e');
      _hasSeenTutorial = false;
    }
  }

  // Saves the tutorial state to the database
  // Returns true if successful, false otherwise
  Future<bool> saveTutorialState() async {
    try {
      await DatabaseProvider.db.markTutorialAsSeen(_tutorialPreferenceKey);
      _hasSeenTutorial = true;
      return true;
    } catch (e) {
      debugPrint('Error saving tutorial state: $e');
      return false;
    }
  }

  // Shows the tutorial overlay and saves state
  // Checks if the context is still valid before showing
  Future<void> showTutorial(BuildContext context) async {
    // Save state first and wait for it to complete
    await saveTutorialState();
    // Only show tutorial if context is still valid
    if (context.mounted) {
      showTutorialOverlay(context, steps: tutorialSteps);
    }
  }

  // Initializes the tutorial with a delay on first launch
  // Only shows if the user hasn't seen it before
  // Timer for delayed initialization
  Timer? _initTimer;

  void initializeWithDelay(
    BuildContext Function() contextProvider,
    bool mounted,
  ) {
    if (!_hasSeenTutorial) {
      _initTimer = Timer(const Duration(milliseconds: 500), () {
        // Check if still mounted before accessing context
        if (mounted) {
          // Only get context when needed and when we're sure mounted is true
          showTutorial(contextProvider());
        }
      });
    }
  }

  // Clean up resources
  @override
  void dispose() {
    _initTimer?.cancel();
    // Don't call notifyListeners after disposing - it causes errors
    super.dispose();
  }

  // Creates a tutorial button widget with an optional notification badge
  // Badge appears if the user hasn't seen the tutorial
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
