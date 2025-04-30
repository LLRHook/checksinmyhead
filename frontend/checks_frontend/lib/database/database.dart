// lib/data/database.dart
import 'dart:io';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:drift/drift.dart' hide Column; // Avoid Column conflict with Flutter
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart' hide Table; // Hide Table from Flutter
import '../models/person.dart';


part 'database.g.dart';

class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get lastUsed => dateTime().withDefault(Constant(DateTime.now()))();
}

class TutorialStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tutorialKey => text().unique()();
  BoolColumn get hasBeenSeen => boolean()();
  DateTimeColumn get lastShownDate => dateTime().nullable()();
}

class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get includeItemsInShare => boolean().withDefault(const Constant(true))();
  BoolColumn get includePersonItemsInShare => boolean().withDefault(const Constant(true))();
  BoolColumn get hideBreakdownInShare => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(Constant(DateTime.now()))();
}

@DriftDatabase(tables: [People, TutorialStates, UserPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      // Create all tables when database is first created
      await migrator.createAll();
      
      // Insert default preferences
      await into(userPreferences).insert(
        const UserPreferencesCompanion(
          id: Value(1), // Single row with ID 1 for app preferences
        )
      );
    },
  );

  // Convert database entity to model
  Person peopleDataToPerson(PeopleData entry) {
    return Person(
      name: entry.name,
      color: Color(entry.colorValue),
      icon: Icons.person, // Default icon
    );
  }

  // Get recent people
  Future<List<Person>> getRecentPeople({int limit = 8}) async {
    final query = select(people)
      ..orderBy([(t) => OrderingTerm.desc(t.lastUsed)])
      ..limit(limit);
    
    final results = await query.get();
    return results.map(peopleDataToPerson).toList();
  }

  // Add person to recents
  Future<void> addPersonToRecent(Person person) async {
    // Check if person already exists
    final query = select(people)
      ..where((p) => p.name.equals(person.name.toLowerCase()));
    
    final existing = await query.getSingleOrNull();
    
    if (existing != null) {
      // Update last used timestamp
      await (update(people)..where((p) => p.id.equals(existing.id)))
        .write(PeopleCompanion(
          colorValue: Value(person.color.value),
          lastUsed: Value(DateTime.now()),
        ));
    } else {
      // Add new person
      await into(people).insert(PeopleCompanion(
        name: Value(person.name),
        colorValue: Value(person.color.value),
        lastUsed: Value(DateTime.now()),
      ));
    }
  }

  // Add multiple people to recents
  Future<void> addPeopleToRecent(List<Person> personList) async {
    for (final person in personList) {
      await addPersonToRecent(person);
    }
  }

  // Tutorial methods
  Future<bool> hasTutorialBeenSeen(String tutorialKey) async {
    final query = select(tutorialStates)
      ..where((t) => t.tutorialKey.equals(tutorialKey));
    
    final result = await query.getSingleOrNull();
    return result?.hasBeenSeen ?? false;
  }
  
  Future<void> markTutorialAsSeen(String tutorialKey) async {
    final query = select(tutorialStates)
      ..where((t) => t.tutorialKey.equals(tutorialKey));
    
    final existing = await query.getSingleOrNull();
    
    if (existing != null) {
      await (update(tutorialStates)..where((t) => t.id.equals(existing.id)))
        .write(TutorialStatesCompanion(
          hasBeenSeen: const Value(true),
          lastShownDate: Value(DateTime.now()),
        ));
    } else {
      await into(tutorialStates).insert(TutorialStatesCompanion(
        tutorialKey: Value(tutorialKey),
        hasBeenSeen: const Value(true),
        lastShownDate: Value(DateTime.now()),
      ));
    }
  }
  
  Future<void> resetTutorial(String tutorialKey) async {
    final query = select(tutorialStates)
      ..where((t) => t.tutorialKey.equals(tutorialKey));
    
    final existing = await query.getSingleOrNull();
    
    if (existing != null) {
      await (update(tutorialStates)..where((t) => t.id.equals(existing.id)))
        .write(const TutorialStatesCompanion(
          hasBeenSeen: Value(false),
        ));
    }
  }
  
  Future<List<String>> getAllSeenTutorials() async {
    final query = select(tutorialStates)
      ..where((t) => t.hasBeenSeen.equals(true));
    
    final results = await query.get();
    return results.map((r) => r.tutorialKey).toList();
  }

  // User Preferences methods
  Future<ShareOptions> getShareOptions() async {
    final prefs = await (select(userPreferences)..where((p) => p.id.equals(1))).getSingleOrNull();
    
    if (prefs == null) {
      // If no preferences exist, insert default preferences
      await into(userPreferences).insert(
        const UserPreferencesCompanion(
          id: Value(1),
        )
      );
      
      // Return default values
      return ShareOptions();
    }
    
    return ShareOptions(
      includeItemsInShare: prefs.includeItemsInShare,
      includePersonItemsInShare: prefs.includePersonItemsInShare,
      hideBreakdownInShare: prefs.hideBreakdownInShare,
    );
  }
  
  Future<void> saveShareOptions(ShareOptions options) async {
    await (update(userPreferences)..where((p) => p.id.equals(1))).write(
      UserPreferencesCompanion(
        includeItemsInShare: Value(options.includeItemsInShare),
        includePersonItemsInShare: Value(options.includePersonItemsInShare),
        hideBreakdownInShare: Value(options.hideBreakdownInShare),
        updatedAt: Value(DateTime.now()),
      )
    );
  }

  // Clear all people (for testing)
  Future<void> clearAllPeople() async {
    await delete(people).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'split_bill.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}