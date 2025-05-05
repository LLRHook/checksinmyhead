import 'database.dart';

class DatabaseProvider {
  // Ensures single instance across the app
  static final DatabaseProvider _instance = DatabaseProvider._internal();

  factory DatabaseProvider() {
    return _instance;
  }

  DatabaseProvider._internal();

  final AppDatabase database = AppDatabase();

  // Global access point for database operations
  static AppDatabase get db => DatabaseProvider().database;
}
