// Billington: Privacy-first receipt spliting
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
import 'package:checks_frontend/services/receipt_validation.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/models/person.dart';

/// Manages the participant list for bill splitting with animations and deduplication.
/// Implements ChangeNotifier pattern for reactive UI updates.
class ParticipantsProvider extends ChangeNotifier {
  final List<Person> _participants = [];
  final Map<String, Animation<double>> _listItemAnimations = {};
  int _colorIndex = 0;
  String? _validationError;
  late final List<Color> _shuffledColors =
      ColorUtils.getParticipantColors()..shuffle();

  // Simple getters
  String? get validationError => _validationError;
  List<Person> get participants => _participants;
  Map<String, Animation<double>> get listItemAnimations => _listItemAnimations;
  bool get hasParticipants => _participants.isNotEmpty;

  /// Adds a new person with automatic color assignment and duplicate prevention.
  /// Returns true if the person was added, false if rejected (invalid name or duplicate).
  bool addPerson(String name, {Color? color}) {
    final trimmedName = name.trim();
    if (!_validateName(trimmedName)) return false;

    _participants.add(
      Person(
        name: trimmedName,
        color: color ?? _shuffledColors[_colorIndex % _shuffledColors.length],
      ),
    );
    _colorIndex++;

    HapticFeedback.lightImpact();
    notifyListeners();
    return true;
  }

  /// Adds an existing Person object if not already in the list
  /// Returns true if person was added, false otherwise
  bool addRecentPerson(Person person) {
    if (!_validateName(person.name)) return false;

    _participants.add(person.freshOccurrence());
    HapticFeedback.selectionClick();
    notifyListeners();
    return true;
  }

  /// Validate every group member before adding any; never silently omit a name.
  bool addGroup(List<Person> members) {
    for (final person in members) {
      if (!_validateName(person.name)) return false;
    }
    for (final person in members) {
      addRecentPerson(person);
    }
    return true;
  }

  bool _validateName(String name) {
    _validationError = receiptParticipantNameError(name, allowEmpty: true);
    if (_validationError != null) {
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Safely removes a person at specified index with haptic feedback
  void removePerson(int index) {
    if (index < 0 || index >= _participants.length) return;

    _participants.removeAt(index);
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  // Suggestions add another occurrence; their labels do not select existing rows.
  bool isPersonSelected(Person person) => false;
  void toggleRecentPerson(Person person) => addRecentPerson(person);

  void renamePerson(int index, String label) {
    if (index < 0 || index >= _participants.length || !_validateName(label)) {
      return;
    }
    _participants[index] = _participants[index].copyWith(name: label);
    notifyListeners();
  }

  /// Resets provider state entirely
  void clearAll() {
    _validationError = null;
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
}
