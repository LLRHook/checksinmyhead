import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/models/person.dart';

class RecentPeopleManager {
  static const String _storageKey = 'recent_people';
  static const int _maxRecentPeople = 8;
  
  /// Load recent people from storage
  static Future<List<Person>> loadRecentPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final recentPeopleJson = prefs.getStringList(_storageKey) ?? [];

    if (recentPeopleJson.isEmpty) {
      return [];
    }
    
    try {
      return recentPeopleJson.map((json) {
        final map = jsonDecode(json);
        return Person(name: map['name'], color: Color(map['color']));
      }).toList();
    } catch (e) {
      // Handle any parsing errors
      debugPrint('Error loading recent people: $e');
      return [];
    }
  }

  /// Save people to recent list
  static Future<void> saveRecentPeople(List<Person> currentParticipants, List<Person> recentPeople) async {
    final prefs = await SharedPreferences.getInstance();

    // Create a combined list prioritizing current participants
    final combinedList = [...currentParticipants];

    // Add recent people not in current participants
    for (final person in recentPeople) {
      if (!combinedList.any((p) => p.name.toLowerCase() == person.name.toLowerCase())) {
        combinedList.add(person);
      }
    }

    // Convert Person objects to JSON strings
    final recentPeopleJson = combinedList.map((person) {
      return jsonEncode({'name': person.name, 'color': person.color.value});
    }).toList();

    // Save the list (up to max number of recent people)
    await prefs.setStringList(
      _storageKey,
      recentPeopleJson.take(_maxRecentPeople).toList(),
    );
  }
}