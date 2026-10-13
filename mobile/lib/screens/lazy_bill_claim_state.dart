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
