import '/models/bill_item.dart';
import '/models/person.dart';

/// Data class to hold the result of item assignment, including items and birthday person
class AssignmentResult {
  final List<BillItem> items;
  final Person? birthdayPerson;

  const AssignmentResult({
    required this.items,
    this.birthdayPerson,
  });
} 