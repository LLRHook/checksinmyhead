import '/models/person.dart';
import '/models/bill_item.dart';

class CalculationUtils {
  /// Calculate a person's amounts (subtotal, tax, tip)
  static Map<String, double> calculatePersonAmounts({
    required Person person,
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required Person? birthdayPerson,
  }) {
    double personSubtotal = 0.0;

    // If using items, calculate from item assignments
    if (items.isNotEmpty) {
      for (var item in items) {
        personSubtotal += item.amountForPerson(person);
      }
    } else {
      // Otherwise, estimate based on final share proportion
      final personTotal = personShares[person] ?? 0.0;
      final totalWithoutExtras = subtotal;
      final extras = tax + tipAmount;

      // If the person is the birthday person with $0 share
      if (personTotal <= 0) {
        return {'subtotal': 0.0, 'tax': 0.0, 'tip': 0.0, 'total': 0.0};
      }

      // Calculate the proportion of the subtotal this person is responsible for
      final proportion = personTotal / (totalWithoutExtras + extras);
      personSubtotal = proportion * totalWithoutExtras;
    }

    // Calculate tax and tip proportionally to subtotal
    final proportion = personSubtotal / subtotal;
    final personTax = tax * proportion;
    final personTip = tipAmount * proportion;

    return {
      'subtotal': personSubtotal,
      'tax': personTax,
      'tip': personTip,
      'total': personSubtotal + personTax + personTip,
    };
  }
}
