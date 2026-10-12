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

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';

class RecentPeopleManager {
  static const int _maxRecentPeople = 12;

  static Future<List<Person>> loadRecentPeople() async {
    try {
      return await DatabaseProvider.db.getRecentPeople(limit: _maxRecentPeople);
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveRecentPeople(List<Person> currentParticipants) async {
    try {
      await DatabaseProvider.db.addPeopleToRecent(currentParticipants);
    } catch (e) {
      debugPrint('Error saving recent people: $e');
    }
  }
}
