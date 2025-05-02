// lib/data/database.dart
import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:drift/drift.dart'
    hide Column; // Avoid Column conflict with Flutter
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart' hide Table; // Hide Table from Flutter
import '../models/person.dart';

//generated with dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get lastUsed =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

class TutorialStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tutorialKey => text().unique()();
  BoolColumn get hasBeenSeen => boolean()();
  DateTimeColumn get lastShownDate => dateTime().nullable()();
}

class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get includeItemsInShare =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includePersonItemsInShare =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get hideBreakdownInShare =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

// Add this class to your database.dart file
class RecentBills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get participants => text()(); // Stored as JSON array of names
  IntColumn get participantCount => integer()();
  RealColumn get total => real()();
  TextColumn get date => text()(); // ISO 8601 format
  RealColumn get subtotal => real()();
  RealColumn get tax => real()();
  RealColumn get tipAmount => real()();
  RealColumn get tipPercentage =>
      real().nullable()(); // New column for tip percentage
  TextColumn get items => text().nullable()(); // Stored as JSON
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF2196F3))(); // Default to blue
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

@DriftDatabase(tables: [People, TutorialStates, UserPreferences, RecentBills])
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
        ),
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
    final query =
        select(people)
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
      await (update(people)..where((p) => p.id.equals(existing.id))).write(
        PeopleCompanion(
          colorValue: Value(person.color.value),
          lastUsed: Value(DateTime.now()),
        ),
      );
    } else {
      // Add new person
      await into(people).insert(
        PeopleCompanion(
          name: Value(person.name),
          colorValue: Value(person.color.value),
          lastUsed: Value(DateTime.now()),
        ),
      );
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
      await (update(tutorialStates)
        ..where((t) => t.id.equals(existing.id))).write(
        TutorialStatesCompanion(
          hasBeenSeen: const Value(true),
          lastShownDate: Value(DateTime.now()),
        ),
      );
    } else {
      await into(tutorialStates).insert(
        TutorialStatesCompanion(
          tutorialKey: Value(tutorialKey),
          hasBeenSeen: const Value(true),
          lastShownDate: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> resetTutorial(String tutorialKey) async {
    final query = select(tutorialStates)
      ..where((t) => t.tutorialKey.equals(tutorialKey));

    final existing = await query.getSingleOrNull();

    if (existing != null) {
      await (update(tutorialStates)..where(
        (t) => t.id.equals(existing.id),
      )).write(const TutorialStatesCompanion(hasBeenSeen: Value(false)));
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
    final prefs =
        await (select(userPreferences)
          ..where((p) => p.id.equals(1))).getSingleOrNull();

    if (prefs == null) {
      // If no preferences exist, insert default preferences
      await into(
        userPreferences,
      ).insert(const UserPreferencesCompanion(id: Value(1)));

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
      ),
    );
  }

  // Clear all people (for testing)
  Future<void> clearAllPeople() async {
    await delete(people).go();
  }

  //-- RECENT BILL METHODS --//
  // Maximum number of recent bills to store
  static const int maxRecentBills = 30;

  // Save a bill to recent bills
  // Update this method in your database_provider.dart or database.dart file
  // In database.dart, update the saveBill method:
  Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    Person? birthdayPerson,
    double tipPercentage = 0,
    bool isCustomTipAmount = false, // Add this parameter
  }) async {
    // Convert participants to a JSON-friendly format
    final participantNames = participants.map((p) => p.name).toList();
    final participantsJson = jsonEncode(participantNames);

    // Convert items to JSON with assignments
    String? itemsJson;
    if (items.isNotEmpty) {
      final itemsData =
          items.map((item) {
            // Create a simplified map of assignments by person name
            Map<String, double> assignmentsByName = {};

            // Convert Person keys to person names
            item.assignments.forEach((person, percentage) {
              assignmentsByName[person.name] = percentage;
            });

            return {
              'name': item.name,
              'price': item.price,
              'isAlcohol': item.isAlcohol,
              'assignments':
                  assignmentsByName, // Store assignments by person name
              'alcoholTaxPortion': item.alcoholTaxPortion,
              'alcoholTipPortion': item.alcoholTipPortion,
            };
          }).toList();

      itemsJson = jsonEncode(itemsData);
    }

    final companion = RecentBillsCompanion(
      participants: Value(participantsJson),
      participantCount: Value(participants.length),
      total: Value(total),
      date: Value(DateTime.now().toIso8601String()),
      subtotal: Value(subtotal),
      tax: Value(tax),
      tipAmount: Value(tipAmount),
      tipPercentage: Value(tipPercentage),
      items: Value(itemsJson),
      // Use the primary participant's color if available
      colorValue:
          participants.isNotEmpty
              ? Value(participants.first.color.value)
              : const Value.absent(),
    );

    // First, check how many recent bills we have
    final count = await select(recentBills).get().then((bills) => bills.length);

    // If we're at the limit, delete the oldest one
    if (count >= maxRecentBills) {
      final oldest =
          await (select(recentBills)
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                ..limit(1))
              .getSingle();

      await (delete(recentBills)..where((t) => t.id.equals(oldest.id))).go();
    }

    // Insert the new bill
    await into(recentBills).insert(companion);
  }

  // Get recent bills
  Future<List<RecentBill>> getRecentBills() async {
    final query = select(recentBills)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.get();
  }

  // Delete a specific bill
  Future<void> deleteBill(int id) async {
    await (delete(recentBills)..where((t) => t.id.equals(id))).go();
  }

  // Clear all bills
  Future<void> clearAllBills() async {
    await delete(recentBills).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'split_bill.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
