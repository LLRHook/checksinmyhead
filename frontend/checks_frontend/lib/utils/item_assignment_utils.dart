import 'package:flutter/material.dart';
import '../models/person.dart';
import '../models/bill_item.dart';

// Helper functions for item assignment

// Check if a person is already assigned to an item
bool isPersonAssignedToItem(BillItem item, Person person) {
  return item.assignments.containsKey(person) && item.assignments[person]! > 0;
}

// Get all assigned people for an item
List<Person> getAssignedPeopleForItem(BillItem item) {
  return item.assignments.entries
      .where((entry) => entry.value > 0)
      .map((entry) => entry.key)
      .toList();
}

// Balance an item between specific assignees
Map<Person, double> balanceItemBetweenAssignees(List<Person> assignedPeople) {
  if (assignedPeople.isEmpty) return {};

  Map<Person, double> newAssignments = {};
  double percentage = 100.0 / assignedPeople.length;

  for (var person in assignedPeople) {
    newAssignments[person] = percentage;
  }

  return newAssignments;
}

// Create a pre-distributed assignment map
Map<Person, double> createPresetAssignments(
  List<Person> participants,
  List<Person> preselectedPeople,
) {
  Map<Person, double> workingAssignments = {};

  // Initialize all participants with 0%
  for (var person in participants) {
    workingAssignments[person] = 0.0;
  }

  // Distribute 100% evenly among preselected people
  if (preselectedPeople.isNotEmpty) {
    double evenShare = 100.0 / preselectedPeople.length;
    for (var person in preselectedPeople) {
      workingAssignments[person] = evenShare;
    }
  }

  return workingAssignments;
}
