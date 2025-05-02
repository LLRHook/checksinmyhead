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
