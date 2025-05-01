import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/person.dart';

class RecentPeopleManager {
  static const int _maxRecentPeople = 8;

  /// Load recent people from storage
  static Future<List<Person>> loadRecentPeople() async {
    try {
      return await DatabaseProvider.db.getRecentPeople(limit: _maxRecentPeople);
    } catch (e) {
      return [];
    }
  }

  /// Save people to recent list
  static Future<void> saveRecentPeople(
    List<Person> currentParticipants,
    List<Person> recentPeople,
  ) async {
    try {
      // Add current participants first (most recent)
      await DatabaseProvider.db.addPeopleToRecent(currentParticipants);
    } catch (e) {}
  }
}
