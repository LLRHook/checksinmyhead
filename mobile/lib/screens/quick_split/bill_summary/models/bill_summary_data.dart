import '/models/person.dart';
import '/models/bill_item.dart';

/// Data container class that encapsulates all bill-related information
/// to simplify state management and avoid prop drilling across widgets
class BillSummaryData {
  final List<Person> participants;
  final Map<Person, double> personShares;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final Person? birthdayPerson;
  final double tipPercentage;
  final bool isCustomTipAmount;

  const BillSummaryData({
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
    this.tipPercentage = 0.0,
    this.isCustomTipAmount = false,
  });

  /// Returns participants sorted by their payment amount in descending order
  /// Useful for displaying participants in order of contribution
  List<Person> get sortedParticipants {
    final sorted = List<Person>.from(participants);
    sorted.sort((a, b) {
      final aShare = personShares[a] ?? 0;
      final bShare = personShares[b] ?? 0;
      return bShare.compareTo(aShare);
    });
    return sorted;
  }
}
