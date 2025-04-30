// lib/data/database_provider.dart
import 'database.dart';

class DatabaseProvider {
  // Singleton instance
  static final DatabaseProvider _instance = DatabaseProvider._internal();

  // Factory constructor
  factory DatabaseProvider() {
    return _instance;
  }

  // Private constructor
  DatabaseProvider._internal();

  // Single database instance
  final AppDatabase database = AppDatabase();

  // Getter for easy access
  static AppDatabase get db => DatabaseProvider().database;
}
