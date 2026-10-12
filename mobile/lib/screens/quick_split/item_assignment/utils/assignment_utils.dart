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

import 'package:checks_frontend/screens/quick_split/item_assignment/models/assignment_data.dart';
import 'package:flutter/material.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';

class AssignmentUtils {
  /// Uses a person's color only when they own the entire item.
  static Color getAssignmentColor(BillItem item, Color defaultColor) {
    if (item.assignments.length == 1 &&
        (item.assignments.values.first - 100.0).abs() < 0.01) {
      return item.assignments.keys.first.color.withValues(alpha: .2);
    }
    return defaultColor;
  }

  /// Whether [person] has a positive assignment for [item].
  static bool isPersonAssignedToItem(BillItem item, Person person) {
    return item.assignments.containsKey(person) &&
        item.assignments[person]! > 0;
  }

  /// People with positive assignments for [item].
  static List<Person> getAssignedPeopleForItem(BillItem item) {
    return item.assignments.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// Splits an item's assignment equally among [assignedPeople].
  static Map<Person, double> balanceItemBetweenAssignees(
    List<Person> assignedPeople,
  ) {
    return _splitPercentages(assignedPeople);
  }

  /// Fraction of the bill total owed by [person].
  static double getPersonBillPercentage(Person person, AssignmentData data) {
    final total = data.total > 0 ? data.total : 1.0;
    final share = data.personFinalShares[person] ?? 0.0;
    return (share / total).clamp(0.0, 1.0);
  }

  /// Initializes totals and shares for a new bill.
  static AssignmentData calculateInitialAssignments(AssignmentData data) {
    Map<Person, double> personTotals = {};
    double unassignedAmount = 0.0;

    if (data.items.isEmpty) {
      final payingPeople = _payingPeopleCount(data);

      double evenShare = payingPeople > 0 ? data.subtotal / payingPeople : 0.0;

      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          personTotals[person] = 0.0;
        } else {
          personTotals[person] = evenShare;
        }
      }

      unassignedAmount = 0.0;
    } else {
      unassignedAmount = data.subtotal;

      for (var person in data.participants) {
        personTotals[person] = 0.0;
      }
    }

    final personFinalShares = calculateFinalShares(
      data.copyWith(
        personTotals: personTotals,
        unassignedAmount: unassignedAmount,
      ),
    );

    return data.copyWith(
      personTotals: personTotals,
      personFinalShares: personFinalShares,
      unassignedAmount: unassignedAmount,
    );
  }

  /// Calculates each participant's final amount, including tax and tip.
  static Map<Person, double> calculateFinalShares(AssignmentData data) {
    Map<Person, double> newShares = {};

    double totalAssigned = data.personTotals.values.fold(
      0,
      (sum, amount) => sum + amount,
    );

    if (totalAssigned > 0) {
      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          newShares[person] = 0.0;
          continue;
        }

        double personSubtotal = data.personTotals[person] ?? 0.0;
        double personPercentage = personSubtotal / totalAssigned;

        double personTax = data.tax * personPercentage;
        double personTip = data.tipAmount * personPercentage;

        newShares[person] = personSubtotal + personTax + personTip;
      }
    } else {
      final payingPeople = _payingPeopleCount(data);

      if (payingPeople > 0) {
        double evenShare = data.total / payingPeople;

        for (var person in data.participants) {
          if (data.birthdayPerson == person) {
            newShares[person] = 0.0;
          } else {
            newShares[person] = evenShare;
          }
        }
      }
    }

    return applyLargestRemainder(newShares, data.total);
  }

  /// Rounds shares to cents and distributes leftovers by largest remainder.
  static Map<Person, double> applyLargestRemainder(
    Map<Person, double> shares,
    double targetTotal,
  ) {
    if (shares.isEmpty) return shares;

    final result = <Person, double>{};
    final remainders = <Person, double>{};

    int totalCents = (targetTotal * 100).round();
    int allocatedCents = 0;

    for (final entry in shares.entries) {
      int floored = (entry.value * 100).floor();
      result[entry.key] = floored / 100.0;
      remainders[entry.key] = (entry.value * 100) - floored;
      allocatedCents += floored;
    }

    int remainingCents = totalCents - allocatedCents;
    final sorted =
        remainders.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < remainingCents && i < sorted.length; i++) {
      result[sorted[i].key] = result[sorted[i].key]! + 0.01;
    }

    return result;
  }

  /// Updates an item's assignments and recalculates bill totals.
  static AssignmentData assignItem(
    AssignmentData data,
    BillItem item,
    Map<Person, double> newAssignments,
  ) {
    item.assignments = newAssignments;

    return _recalculateTotals(data);
  }

  /// Splits 100% evenly among [people].
  static Map<Person, double> splitItemEvenly(List<Person> people) {
    return _splitPercentages(people);
  }

  static Map<Person, double> _splitPercentages(List<Person> people) {
    if (people.isEmpty) return {};

    final basePercent = (10000 ~/ people.length) / 100.0;
    return {
      for (var i = 0; i < people.length; i++)
        people[i]:
            i == 0 ? 100.0 - basePercent * (people.length - 1) : basePercent,
    };
  }

  /// Removes the birthday person's assignments and redistributes their share.
  static AssignmentData unassignItemsFromBirthdayPerson(
    AssignmentData data,
    Person birthdayPerson,
  ) {
    bool changesDetected = false;

    for (var item in data.items) {
      if (item.assignments.containsKey(birthdayPerson)) {
        double birthdayPersonPercentage =
            item.assignments[birthdayPerson] ?? 0.0;

        if (birthdayPersonPercentage > 0) {
          changesDetected = true;

          Map<Person, double> newAssignments = Map.from(item.assignments);
          newAssignments.remove(birthdayPerson);

          if (newAssignments.isNotEmpty) {
            double totalRemaining = newAssignments.values.fold(
              0.0,
              (sum, value) => sum + value,
            );

            if (totalRemaining > 0) {
              double scaleFactor = 100.0 / totalRemaining;

              newAssignments.forEach((key, value) {
                newAssignments[key] = value * scaleFactor;
              });
            }
          }

          item.assignments = newAssignments;
        }
      }
    }

    if (changesDetected) {
      return _recalculateTotals(data);
    }

    return data;
  }

  static AssignmentData _recalculateTotals(AssignmentData data) {
    final personTotals = {
      for (final person in data.participants)
        person: data.items.fold<double>(
          0,
          (total, item) => total + item.amountForPerson(person),
        ),
    };
    final assignedTotal = personTotals.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final unassignedAmount = data.subtotal - assignedTotal;
    final updatedData = data.copyWith(
      personTotals: personTotals,
      unassignedAmount: unassignedAmount,
    );

    return updatedData.copyWith(
      personFinalShares: calculateFinalShares(updatedData),
    );
  }

  static int _payingPeopleCount(AssignmentData data) =>
      data.participants.length - (data.birthdayPerson == null ? 0 : 1);

  /// Splits unassigned amounts across participants who owe money.
  static AssignmentData splitUnassignedAmountEvenly(AssignmentData data) {
    if (data.unassignedAmount <= 0) return data;

    final payingPeople = _payingPeopleCount(data);
    if (payingPeople <= 0) return data;

    final evenShare = data.unassignedAmount / payingPeople;
    var personTotals = Map<Person, double>.from(data.personTotals);

    for (var person in data.participants) {
      if (person != data.birthdayPerson) {
        personTotals[person] = (personTotals[person] ?? 0.0) + evenShare;
      }
    }

    if (data.items.isNotEmpty) {
      for (var item in data.items) {
        final assignedPercentage = item.assignments.values.fold(
          0.0,
          (sum, value) => sum + value,
        );
        if (assignedPercentage >= 100.0) continue;

        final unassignedPercentage = 100.0 - assignedPercentage;
        final newAssignments = Map<Person, double>.from(item.assignments);
        for (var person in data.participants) {
          if (person != data.birthdayPerson) {
            newAssignments[person] =
                (newAssignments[person] ?? 0.0) +
                unassignedPercentage / payingPeople;
          }
        }
        item.assignments = newAssignments;
      }

      personTotals = {
        for (final person in data.participants)
          person: data.items.fold<double>(
            0,
            (total, item) => total + item.amountForPerson(person),
          ),
      };
    }

    final updatedData = data.copyWith(
      personTotals: personTotals,
      unassignedAmount: 0.0,
    );
    return updatedData.copyWith(
      personFinalShares: calculateFinalShares(updatedData),
    );
  }
}
