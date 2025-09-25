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

import 'person.dart';

/// Represents an item on a bill with its cost distribution among people
///
/// A [BillItem] contains a name, price, and assignments of percentages to people.
/// The assignments map tracks what percentage of the item's cost each person is responsible for.
///
/// Example:
/// ```dart
/// final item = BillItem(
///   name: "Pizza",
///   price: 20.00,
///   assignments: {person1: 50, person2: 50}
/// );
/// ```
///
/// Key features:
/// * Handles percentage-based cost splitting
/// * Provides safe access to person assignments with null coalescing
/// * Implements immutable copying via [copyWith]
///
/// Note: Assignment percentages should sum to 100 for proper cost distribution,
/// though this is not enforced by the class to allow flexibility in calculations.

class BillItem {
  final String name;
  final double price;
  Map<Person, double> assignments;

  BillItem({
    required this.name,
    required this.price,
    required this.assignments,
  });

  // Get the amount owed by a specific person
  double amountForPerson(Person person) {
    return price * (assignments[person] ?? 0) / 100;
  }

  BillItem copyWith({
    String? name,
    double? price,
    Map<Person, double>? assignments,
    bool? isAlcohol,
    double? alcoholTaxPortion,
    double? alcoholTipPortion,
  }) {
    return BillItem(
      name: name ?? this.name,
      price: price ?? this.price,
      assignments: assignments ?? this.assignments,
    );
  }
}
