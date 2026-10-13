/// Whether a person may change item selections in the lazy bill picker.
bool canChangeLazyBillSelection({required bool saving, required bool paid}) =>
    !saving && !paid;

bool lazyAssignmentsEqual(
  List<Map<String, dynamic>> left,
  List<Map<String, dynamic>> right,
) {
  if (left.length != right.length) return false;
  final sortedLeft = [...left]..sort(
    (a, b) => (a['person_name'] as String).toLowerCase().compareTo(
      (b['person_name'] as String).toLowerCase(),
    ),
  );
  final sortedRight = [...right]..sort(
    (a, b) => (a['person_name'] as String).toLowerCase().compareTo(
      (b['person_name'] as String).toLowerCase(),
    ),
  );
  for (var index = 0; index < sortedLeft.length; index++) {
    if ((sortedLeft[index]['person_name'] as String).toLowerCase() !=
            (sortedRight[index]['person_name'] as String).toLowerCase() ||
        (((sortedLeft[index]['percentage'] as num).toDouble()) -
                    ((sortedRight[index]['percentage'] as num).toDouble()))
                .abs() >=
            0.01) {
      return false;
    }
  }
  return true;
}

bool hasPaidLazyAssignment(
  List<Map<String, dynamic>> assignments,
  List<Map<String, dynamic>> shares,
) {
  final paidPeople =
      shares
          .where((share) => share['paid'] == true)
          .map((share) => (share['person_name'] as String).toLowerCase())
          .toSet();
  return assignments.any(
    (assignment) => paidPeople.contains(
      (assignment['person_name'] as String).toLowerCase(),
    ),
  );
}

bool isLazyItemFullyPaid(
  List<Map<String, dynamic>> assignments,
  List<Map<String, dynamic>> shares,
) {
  if (assignments.isEmpty) return false;
  final assignedPercentage = assignments.fold<double>(
    0,
    (sum, assignment) => sum + (assignment['percentage'] as num).toDouble(),
  );
  if (assignedPercentage < 99.99) return false;
  final paidNames =
      shares
          .where((share) => share['paid'] == true)
          .map((share) => (share['person_name'] as String).toLowerCase())
          .toSet();
  return assignments.every(
    (assignment) =>
        paidNames.contains((assignment['person_name'] as String).toLowerCase()),
  );
}

double remainingLazyPercentage(
  List<Map<String, dynamic>> assignments, {
  String? excludingPerson,
}) {
  final assigned = assignments.fold<double>(
    0,
    (sum, assignment) =>
        (assignment['person_name'] as String).toLowerCase() ==
                excludingPerson?.toLowerCase()
            ? sum
            : sum + (assignment['percentage'] as num).toDouble(),
  );
  return (100 - assigned).clamp(0, 100).toDouble();
}

List<Map<String, dynamic>> setLazyAssignmentPercentage(
  List<Map<String, dynamic>> assignments,
  String personName,
  double percentage,
) {
  final others =
      assignments
          .where(
            (assignment) =>
                (assignment['person_name'] as String).toLowerCase() !=
                personName.toLowerCase(),
          )
          .toList();
  final available = remainingLazyPercentage(others);
  if (available < 1) return others;
  final share = percentage.round().clamp(1, available.floor());
  if (share < 1) return others;
  return [
    ...others,
    {'person_name': personName, 'percentage': share.toDouble()},
  ];
}

List<Map<String, dynamic>> removeLazyAssignmentLeavingRemainder(
  List<Map<String, dynamic>> assignments,
  String personName,
) =>
    assignments
        .where(
          (assignment) =>
              (assignment['person_name'] as String).toLowerCase() !=
              personName.toLowerCase(),
        )
        .toList();

List<Map<String, dynamic>>? createLazySplitAssignments(
  String personName,
  String otherNames,
  double personPercentage,
) {
  final names = <String, String>{};
  for (final part in otherNames.split(',')) {
    final name = part.trim();
    if (name.isEmpty || name.toLowerCase() == personName.toLowerCase()) {
      continue;
    }
    final displayName = name.length > 30 ? name.substring(0, 30) : name;
    names.putIfAbsent(displayName.toLowerCase(), () => displayName);
  }
  if (names.isEmpty || !personPercentage.isFinite) return null;
  final percentage = personPercentage.round().clamp(1, 99).toDouble();
  final participants = names.values.toList();
  final eachOtherPercentage = (100 - percentage) / participants.length;
  return [
    {'person_name': personName, 'percentage': percentage},
    for (var index = 0; index < participants.length; index++)
      {
        'person_name': participants[index],
        'percentage':
            index == participants.length - 1
                ? 100 -
                    percentage -
                    eachOtherPercentage * (participants.length - 1)
                : eachOtherPercentage,
      },
  ];
}

List<Map<String, dynamic>> removeLazyAssignment(
  List<Map<String, dynamic>> assignments,
  String personName,
) {
  final remaining =
      assignments
          .where(
            (assignment) =>
                (assignment['person_name'] as String).toLowerCase() !=
                personName.toLowerCase(),
          )
          .toList();
  if (remaining.isEmpty) return [];
  final total = remaining.fold<double>(
    0,
    (sum, assignment) => sum + (assignment['percentage'] as num).toDouble(),
  );
  if (total <= 0) return [];
  var assigned = 0.0;
  return List.generate(remaining.length, (index) {
    final percentage =
        index == remaining.length - 1
            ? 100 - assigned
            : (remaining[index]['percentage'] as num).toDouble() / total * 100;
    assigned += percentage;
    return {
      'person_name': remaining[index]['person_name'],
      'percentage': percentage,
    };
  });
}
