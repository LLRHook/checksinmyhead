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
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';

class PeopleGroupWithMembers {
  final PeopleGroup group;
  final List<Person> members;

  PeopleGroupWithMembers({required this.group, required this.members});
}

class GroupManager {
  static Future<List<PeopleGroupWithMembers>> loadSavedGroups() async {
    try {
      final db = DatabaseProvider.db;
      final groups = await db.getSavedGroups();
      final result = <PeopleGroupWithMembers>[];
      for (final group in groups) {
        final members = await db.getGroupMembers(group.id);
        result.add(PeopleGroupWithMembers(group: group, members: members));
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  static Future<List<PeopleGroupWithMembers>> loadSuggestedGroups() async {
    try {
      final db = DatabaseProvider.db;
      final groups = await db.getSuggestedGroups();
      final result = <PeopleGroupWithMembers>[];
      for (final group in groups) {
        final members = await db.getGroupMembers(group.id);
        result.add(PeopleGroupWithMembers(group: group, members: members));
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  static Future<int?> createGroup(String name, List<Person> members) async {
    try {
      final db = DatabaseProvider.db;
      final personIds = <int>[];
      for (final member in members) {
        final personData = await db.getPersonByName(member.name);
        if (personData != null) {
          personIds.add(personData.id);
        }
      }
      if (personIds.length < 2) return null;
      final colorValue = members.first.color.toARGB32();
      return await db.createGroup(name, personIds, colorValue);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteGroup(int groupId) async {
    try {
      await DatabaseProvider.db.deleteGroup(groupId);
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  static Future<void> renameGroup(int groupId, String newName) async {
    try {
      await DatabaseProvider.db.renameGroup(groupId, newName);
    } catch (e) {
      debugPrint('Error renaming group: $e');
    }
  }

  static Future<void> updateGroupMembers(int groupId, List<Person> members) async {
    try {
      final db = DatabaseProvider.db;
      final personIds = <int>[];
      for (final member in members) {
        final personData = await db.getPersonByName(member.name);
        if (personData != null) {
          personIds.add(personData.id);
        }
      }
      if (personIds.length >= 2) {
        await db.updateGroupMembers(groupId, personIds);
      }
    } catch (e) {
      debugPrint('Error updating group members: $e');
    }
  }

  static Future<void> markGroupUsed(int groupId) async {
    try {
      await DatabaseProvider.db.updateGroupLastUsed(groupId);
    } catch (e) {
      debugPrint('Error updating group lastUsed: $e');
    }
  }

  static Future<void> saveSuggestedGroup(int groupId, String name) async {
    try {
      await DatabaseProvider.db.saveSuggestedGroup(groupId, name);
    } catch (e) {
      debugPrint('Error saving suggested group: $e');
    }
  }

  /// Analyzes recent bills to detect co-occurring participant groups.
  /// Clears old suggestions and creates new ones.
  static Future<void> refreshSuggestions() async {
    try {
      final db = DatabaseProvider.db;
      final recentBills = await db.getRecentBills();
      final bills = recentBills.take(20).toList();
      if (bills.length < 3) return;

      final billParticipants = <List<String>>[];
      for (final bill in bills) {
        try {
          final names = (jsonDecode(bill.participants) as List)
              .cast<String>()
              .map((n) => n.toLowerCase())
              .toList();
          if (names.length >= 2) {
            billParticipants.add(names);
          }
        } catch (_) {}
      }

      final coOccurrences = <String, int>{};
      for (final names in billParticipants) {
        final sorted = List<String>.from(names)..sort();
        final subsets = _generateSubsets(sorted, 2, 5);
        for (final subset in subsets) {
          final key = subset.join(',');
          coOccurrences[key] = (coOccurrences[key] ?? 0) + 1;
        }
      }

      final frequent = coOccurrences.entries
          .where((e) => e.value >= 3)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final savedGroups = await loadSavedGroups();
      final savedMemberSets = savedGroups.map((g) {
        final names = g.members.map((m) => m.name.toLowerCase()).toList()..sort();
        return names.join(',');
      }).toSet();

      final suggestions = frequent
          .where((e) => !savedMemberSets.contains(e.key))
          .take(3)
          .toList();

      // Remove suggestions that are subsets of other suggestions
      final filteredSuggestions = <MapEntry<String, int>>[];
      for (final suggestion in suggestions) {
        final names = suggestion.key.split(',').toSet();
        final isSubset = suggestions.any((other) {
          if (other.key == suggestion.key) return false;
          final otherNames = other.key.split(',').toSet();
          return names.every(otherNames.contains) && other.value >= suggestion.value;
        });
        if (!isSubset) {
          filteredSuggestions.add(suggestion);
        }
      }

      await db.clearSuggestedGroups();

      for (final suggestion in filteredSuggestions.take(3)) {
        final names = suggestion.key.split(',');
        final personIds = <int>[];
        int? firstColor;
        for (final name in names) {
          final personData = await db.getPersonByName(name);
          if (personData != null) {
            personIds.add(personData.id);
            firstColor ??= personData.colorValue;
          }
        }
        if (personIds.length >= 2) {
          await db.createSuggestedGroup(personIds, firstColor ?? 0xFF64748B);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing suggestions: $e');
    }
  }

  static List<List<String>> _generateSubsets(
    List<String> sorted, int minSize, int maxSize,
  ) {
    final results = <List<String>>[];
    final n = sorted.length;
    final cappedMax = maxSize < n ? maxSize : n;
    for (int size = minSize; size <= cappedMax; size++) {
      _combine(sorted, size, 0, <String>[], results);
    }
    return results;
  }

  static void _combine(
    List<String> list, int size, int start,
    List<String> current, List<List<String>> results,
  ) {
    if (current.length == size) {
      results.add(List<String>.from(current));
      return;
    }
    for (int i = start; i < list.length; i++) {
      current.add(list[i]);
      _combine(list, size, i + 1, current, results);
      current.removeLast();
    }
  }
}
