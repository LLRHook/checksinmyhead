import 'person.dart';

class BillItem {
  final String name;
  final double price;
  Map<Person, double> assignments; // Maps person to percentage (0-100)
  final bool isAlcohol;

  // New fields for alcohol calculations
  double? alcoholTaxPortion; // Portion of alcohol tax for this item
  double? alcoholTipPortion; // Portion of alcohol tip for this item

  BillItem({
    required this.name,
    required this.price,
    required this.assignments,
    this.isAlcohol = false,
    this.alcoholTaxPortion,
    this.alcoholTipPortion,
  });

  // Get the amount owed by a specific person
  double amountForPerson(Person person) {
    return price * (assignments[person] ?? 0) / 100;
  }

  double get totalCost {
    double total = price;
    if (isAlcohol) {
      total += (alcoholTaxPortion ?? 0);
      total += (alcoholTipPortion ?? 0);
    }
    return total;
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
      isAlcohol: isAlcohol ?? this.isAlcohol,
      alcoholTaxPortion: alcoholTaxPortion ?? this.alcoholTaxPortion,
      alcoholTipPortion: alcoholTipPortion ?? this.alcoholTipPortion,
    );
  }
}
