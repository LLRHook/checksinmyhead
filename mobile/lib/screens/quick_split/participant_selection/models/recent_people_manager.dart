import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';

/// Manages the storage and retrieval of recently selected people,
/// implementing a "recently used" pattern with size limitations
class RecentPeopleManager {
  // Maximum number of people to store in recent history
  static const int _maxRecentPeople = 12;

  /// Retrieves up to [_maxRecentPeople] most recent people from database
  /// Returns empty list if database operation fails
  static Future<List<Person>> loadRecentPeople() async {
    try {
      return await DatabaseProvider.db.getRecentPeople(limit: _maxRecentPeople);
    } catch (e) {
      return [];
    }
  }

  /// Updates recent people list with new participants. Management done in the database's [_addPeopleToRecent] method.
  static Future<void> saveRecentPeople(
    List<Person> currentParticipants,
    List<Person> recentPeople,
  ) async {
    try {
      await DatabaseProvider.db.addPeopleToRecent(currentParticipants);
    } catch (e) {
      debugPrint('Error saving recent people: $e');
    }
  }
}
