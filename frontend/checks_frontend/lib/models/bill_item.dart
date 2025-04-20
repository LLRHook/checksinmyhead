import 'person.dart';

class BillItem {
  final String name;
  final double price;
  Map<Person, double> assignments; // Maps person to percentage (0-100)

  BillItem({
    required this.name,
    required this.price,
    required this.assignments,
  });

  // Get the amount owed by a specific person
  double amountForPerson(Person person) {
    return price * (assignments[person] ?? 0) / 100;
  }
}
