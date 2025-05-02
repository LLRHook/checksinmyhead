import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';

class ParticipantsProvider extends ChangeNotifier {
  final List<Person> _participants = [];
  final Map<String, Animation<double>> _listItemAnimations = {};
  int _colorIndex = 0;

  // Getters
  List<Person> get participants => _participants;
  Map<String, Animation<double>> get listItemAnimations => _listItemAnimations;
  bool get hasParticipants => _participants.isNotEmpty;

  /// Add a new person to the participants list
  void addPerson(String name, {Color? color}) {
    if (name.trim().isEmpty) return;

    // Check if this name already exists
    if (_participants.any(
      (p) => p.name.toLowerCase() == name.trim().toLowerCase(),
    )) {
      return;
    }

    final colors = ColorUtils.getParticipantColors();

    // Add new person
    _participants.add(
      Person(
        name: name.trim(),
        color: color ?? colors[_colorIndex % colors.length],
      ),
    );

    _colorIndex++;

    // Vibrate to confirm addition
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Add a recent person to the participants list
  bool addRecentPerson(Person person) {
    if (_participants.any(
      (p) => p.name.toLowerCase() == person.name.toLowerCase(),
    )) {
      return false; // Person already exists in the list
    }

    _participants.add(person);

    // Vibrate to confirm selection
    HapticFeedback.selectionClick();
    notifyListeners();
    return true;
  }

  /// Remove a person from the participants list
  void removePerson(int index) {
    if (index < 0 || index >= _participants.length) return;

    _participants.removeAt(index);

    // Vibrate to confirm removal
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Check if a person is in the participants list
  bool isPersonSelected(Person person) {
    return _participants.any(
      (p) => p.name.toLowerCase() == person.name.toLowerCase(),
    );
  }

  /// Toggle selection of a recent person
  void toggleRecentPerson(Person person) {
    final isSelected = isPersonSelected(person);

    if (isSelected) {
      _participants.removeWhere(
        (p) => p.name.toLowerCase() == person.name.toLowerCase(),
      );
      HapticFeedback.selectionClick();
    } else {
      addRecentPerson(person);
    }

    notifyListeners();
  }

  /// Clear all participants
  void clearAll() {
    _participants.clear();
    _listItemAnimations.clear();
    notifyListeners();
  }

  /// Register an animation for a person being removed
  void registerAnimation(String personName, Animation<double> animation) {
    _listItemAnimations[personName] = animation;
    notifyListeners();
  }

  /// Unregister an animation when it's complete
  void unregisterAnimation(String personName) {
    _listItemAnimations.remove(personName);
    notifyListeners();
  }
}
