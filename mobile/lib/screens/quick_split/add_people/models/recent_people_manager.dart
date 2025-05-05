import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/person.dart';

/// Manages the storage and retrieval of recently selected people,
/// implementing a "recently used" pattern with size limitations
class RecentPeopleManager {
  // Maximum number of people to store in recent history
  static const int _maxRecentPeople = 8;

  /// Retrieves up to [_maxRecentPeople] most recent people from database
  /// Returns empty list if database operation fails
  static Future<List<Person>> loadRecentPeople() async {
    try {
      return await DatabaseProvider.db.getRecentPeople(limit: _maxRecentPeople);
    } catch (e) {
      return [];
    }
  }

  /// Updates recent people list with new participants
  /// Note: Currently only adds new participants without managing existing entries
  /// TODO: Consider implementing cleanup of old entries to maintain _maxRecentPeople limit
  static Future<void> saveRecentPeople(
    List<Person> currentParticipants,
    List<Person> recentPeople,
  ) async {
    try {
      await DatabaseProvider.db.addPeopleToRecent(currentParticipants);
    } catch (e) {
      // Silent failure - consider adding error logging
    }
  }
}
