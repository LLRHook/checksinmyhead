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
import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart' hide Table, Tab;

// Generated with dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

// Database table for storing person information
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get lastUsed =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

// Database table for tracking tutorial completion status
class TutorialStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tutorialKey => text().unique()();
  BoolColumn get hasBeenSeen => boolean()();
  DateTimeColumn get lastShownDate => dateTime().nullable()();
}

// Database table for user preferences
class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get showAllItems => boolean().withDefault(const Constant(true))();
  BoolColumn get showPersonItems =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showBreakdown => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

// Database table for storing tabs (group trips)
class Tabs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get billIds => text().withDefault(const Constant(''))();
  IntColumn get backendId => integer().nullable()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get shareUrl => text().nullable()();
  BoolColumn get finalized => boolean().withDefault(const Constant(false))();
  TextColumn get memberToken => text().nullable()();
  TextColumn get role => text().nullable()();
  BoolColumn get isRemote => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
}

// Database table for storing bill history
class RecentBills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get billName => text().withDefault(const Constant(''))();
  TextColumn get participants => text()();
  IntColumn get participantCount => integer()();
  RealColumn get total => real()();
  TextColumn get date => text()();
  RealColumn get subtotal => real()();
  RealColumn get tax => real()();
  RealColumn get tipAmount => real()();
  RealColumn get tipPercentage => real().nullable()();
  TextColumn get items => text().nullable()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF2196F3))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();
  TextColumn get shareUrl => text().nullable()();
}

// Main database class handling all database operations
@DriftDatabase(
  tables: [People, TutorialStates, UserPreferences, RecentBills, Tabs],
)
class AppDatabase extends _$AppDatabase {
  static const int maxRecentPeople = 12;

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(recentBills, recentBills.shareUrl);
      }
      if (from < 3) {
        await migrator.createTable(tabs);
      }
      if (from < 4) {
        await migrator.addColumn(tabs, tabs.finalized);
      }
      if (from < 5) {
        await migrator.addColumn(tabs, tabs.memberToken);
        await migrator.addColumn(tabs, tabs.role);
        await migrator.addColumn(tabs, tabs.isRemote);
      }
      if (from < 6) {
        await customStatement('CREATE INDEX IF NOT EXISTS idx_people_last_used ON people(last_used DESC)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_recent_bills_created ON recent_bills(created_at DESC)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_tabs_created ON tabs(created_at DESC)');
      }
    },
  );

  // Converts database person entry to Person model
  Person peopleDataToPerson(PeopleData entry) {
    // Properly capitalize each word in the name for display purposes
    String displayName =
        entry.name.isNotEmpty
            ? entry.name
                .split(' ')
                .map(
                  (word) =>
                      word.isNotEmpty
                          ? word[0].toUpperCase() + word.substring(1)
                          : word,
                )
                .join(' ')
            : entry.name;
    return Person(name: displayName, color: Color(entry.colorValue));
  }

  // Fetches recently used people
  Future<List<Person>> getRecentPeople({int limit = 12}) async {
    final query =
        select(people)
          ..orderBy([(t) => OrderingTerm.desc(t.lastUsed)])
          ..limit(limit);

    final results = await query.get();
    return results.map(peopleDataToPerson).toList();
  }

  Future<void> addPersonToRecent(Person person) async {
    // Always use lowercase for name storage and comparison to prevent duplicates
    final lowercaseName = person.name.toLowerCase();

    final query = select(people)..where((p) => p.name.equals(lowercaseName));

    final existing = await query.getSingleOrNull();

    if (existing != null) {
      await (update(people)..where((p) => p.id.equals(existing.id))).write(
        PeopleCompanion(
          colorValue: Value(person.color.toARGB32()),
          lastUsed: Value(DateTime.now()),
        ),
      );
    } else {
      final count = await select(people).get().then((people) => people.length);

      if (count >= maxRecentPeople) {
        final oldest =
            await (select(people)
                  ..orderBy([(t) => OrderingTerm.asc(t.lastUsed)])
                  ..limit(1))
                .getSingle();

        await (delete(people)..where((p) => p.id.equals(oldest.id))).go();
      }

      await into(people).insert(
        PeopleCompanion(
          name: Value(lowercaseName),
          colorValue: Value(person.color.toARGB32()),
          lastUsed: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> addPeopleToRecent(List<Person> personList) async {
    for (final person in personList) {
      await addPersonToRecent(person);
    }
  }

  // Tutorial tracking methods
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

  // User preferences management
  Future<ShareOptions> getShareOptions() async {
    final prefs =
        await (select(userPreferences)
          ..where((p) => p.id.equals(1))).getSingleOrNull();

    if (prefs == null) {
      await into(
        userPreferences,
      ).insert(const UserPreferencesCompanion(id: Value(1)));

      return ShareOptions();
    }

    return ShareOptions(
      showAllItems: prefs.showAllItems,
      showPersonItems: prefs.showPersonItems,
      showBreakdown: prefs.showBreakdown,
    );
  }

  Future<void> saveShareOptions(ShareOptions options) async {
    await (update(userPreferences)..where((p) => p.id.equals(1))).write(
      UserPreferencesCompanion(
        showAllItems: Value(options.showAllItems),
        showPersonItems: Value(options.showPersonItems),
        showBreakdown: Value(options.showBreakdown),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Recent bills management (max 30 bills stored)
  static const int maxRecentBills = 30;

  // Stores a new bill in history
  Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    String billName = '',
    double tipPercentage = 0,
    bool isCustomTipAmount = false,
    String? shareUrl,
  }) async {
    final participantNames = participants.map((p) => p.name).toList();
    final participantsJson = jsonEncode(participantNames);

    // Check for duplicate bills within the last minute
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    final recentBillsResults =
        await (select(recentBills)
              ..where((b) => b.createdAt.isBiggerThanValue(oneMinuteAgo))
              ..where((b) => b.total.isBetweenValues(total - 0.01, total + 0.01))
              ..where((b) => b.participants.equals(participantsJson)))
            .get();

    // If a similar bill exists within the last minute, skip saving
    if (recentBillsResults.isNotEmpty) {
      return;
    }

    String? itemsJson;
    if (items.isNotEmpty) {
      final itemsData =
          items.map((item) {
            Map<String, double> assignmentsByName = {};
            item.assignments.forEach((person, percentage) {
              assignmentsByName[person.name] = percentage;
            });

            return {
              'name': item.name,
              'price': item.price,
              'assignments': assignmentsByName,
            };
          }).toList();

      itemsJson = jsonEncode(itemsData);
    }

    final companion = RecentBillsCompanion(
      billName: Value(billName),
      participants: Value(participantsJson),
      participantCount: Value(participants.length),
      total: Value(total),
      date: Value(DateTime.now().toIso8601String()),
      subtotal: Value(subtotal),
      tax: Value(tax),
      tipAmount: Value(tipAmount),
      tipPercentage: Value(tipPercentage),
      items: Value(itemsJson),
      colorValue:
          participants.isNotEmpty
              ? Value(participants.first.color.toARGB32())
              : const Value.absent(),
      shareUrl: Value(shareUrl),
    );

    final count = await select(recentBills).get().then((bills) => bills.length);

    if (count >= maxRecentBills) {
      final oldest =
          await (select(recentBills)
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                ..limit(1))
              .getSingle();

      await (delete(recentBills)..where((t) => t.id.equals(oldest.id))).go();
    }

    await into(recentBills).insert(companion);
  }

  Future<List<RecentBill>> getRecentBills() async {
    final query = select(recentBills)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.get();
  }

  Future<void> deleteBill(int id) async {
    await (delete(recentBills)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAllBills() async {
    await delete(recentBills).go();
  }

  /// Updates the name of a bill in the database
  ///
  /// This method allows renaming an existing bill by its ID.
  ///
  /// Parameters:
  /// - id: The unique identifier of the bill to update
  /// - newName: The new name to assign to the bill
  ///
  /// Returns a Future that completes when the operation is finished.
  Future<void> updateBillName(int id, String newName) async {
    await (update(recentBills)..where(
      (t) => t.id.equals(id),
    )).write(RecentBillsCompanion(billName: Value(newName)));
  }

  /// Gets the most recently created bill
  Future<RecentBill?> getMostRecentBill() async {
    final query =
        select(recentBills)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1);
    return query.getSingleOrNull();
  }

  /// Updates the share URL of a bill in the database
  Future<void> updateBillShareUrl(int id, String shareUrl) async {
    await (update(recentBills)..where(
      (t) => t.id.equals(id),
    )).write(RecentBillsCompanion(shareUrl: Value(shareUrl)));
  }

  /// Gets a single bill by its ID
  ///
  /// This method retrieves a specific bill from the database by its ID.
  ///
  /// Parameters:
  /// - id: The unique identifier of the bill to retrieve
  ///
  /// Returns the bill if found, or null if it doesn't exist.
  Future<RecentBill?> getBillById(int id) async {
    final query = select(recentBills)..where((b) => b.id.equals(id));

    return query.getSingleOrNull();
  }

  // Tab management methods

  Future<List<Tab>> getAllTabs() async {
    final query = select(tabs)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<int> insertTab(TabsCompanion tab) async {
    return into(tabs).insert(tab);
  }

  Future<void> updateTab(int id, TabsCompanion companion) async {
    await (update(tabs)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> deleteTab(int id) async {
    await (delete(tabs)..where((t) => t.id.equals(id))).go();
  }

  Future<Tab?> getTabById(int id) async {
    final query = select(tabs)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }
}

// Database connection initialization
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'split_bill.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
