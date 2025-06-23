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

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';

/// Manages the participant list for bill splitting with animations and deduplication.
/// Implements ChangeNotifier pattern for reactive UI updates.
class ParticipantsProvider extends ChangeNotifier {
  final List<Person> _participants = [];
  final Map<String, Animation<double>> _listItemAnimations = {};
  int _colorIndex = 0;

  // Simple getters
  List<Person> get participants => _participants;
  Map<String, Animation<double>> get listItemAnimations => _listItemAnimations;
  bool get hasParticipants => _participants.isNotEmpty;

  /// Adds a new person with automatic color assignment and duplicate prevention
  void addPerson(String name, {Color? color}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    // Prevent duplicates (case-insensitive)
    if (_isNameDuplicate(trimmedName)) return;

    // Cycle through predefined colors when no color is specified
    final colors = ColorUtils.getParticipantColors();
    _participants.add(
      Person(
        name: trimmedName,
        color: color ?? colors[_colorIndex % colors.length],
      ),
    );
    _colorIndex++;

    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Adds an existing Person object if not already in the list
  /// Returns true if person was added, false otherwise
  bool addRecentPerson(Person person) {
    if (_isNameDuplicate(person.name)) return false;

    _participants.add(person);
    HapticFeedback.selectionClick();
    notifyListeners();
    return true;
  }

  /// Safely removes a person at specified index with haptic feedback
  void removePerson(int index) {
    if (index < 0 || index >= _participants.length) return;

    _participants.removeAt(index);
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Case-insensitive check for existing participants
  bool isPersonSelected(Person person) {
    return _isNameDuplicate(person.name);
  }

  /// Toggles a person's inclusion (add if absent, remove if present)
  void toggleRecentPerson(Person person) {
    if (isPersonSelected(person)) {
      _participants.removeWhere(
        (p) => p.name.toLowerCase() == person.name.toLowerCase(),
      );
      HapticFeedback.selectionClick();
    } else {
      addRecentPerson(person);
    }
    notifyListeners();
  }

  /// Resets provider state entirely
  void clearAll() {
    _participants.clear();
    _listItemAnimations.clear();
    notifyListeners();
  }

  /// Tracks animations for smooth list item removal effects
  /// Animation key is person name for identification
  void registerAnimation(String personName, Animation<double> animation) {
    _listItemAnimations[personName] = animation;
    notifyListeners();
  }

  /// Removes completed animations to prevent memory leaks
  void unregisterAnimation(String personName) {
    _listItemAnimations.remove(personName);
    notifyListeners();
  }

  // Private helper method to reduce code duplication for name comparison
  bool _isNameDuplicate(String name) {
    return _participants.any((p) => p.name.toLowerCase() == name.toLowerCase());
  }
}
