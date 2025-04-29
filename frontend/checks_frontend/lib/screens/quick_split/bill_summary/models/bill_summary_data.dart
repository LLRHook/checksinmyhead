import '/models/person.dart';
import '/models/bill_item.dart';

/// A class to hold all the bill summary data to avoid prop drilling
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

  /// Get sorted participants by payment amount (highest first)
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

/// A class to hold share options configuration
class ShareOptions {
  bool includeItemsInShare;
  bool includePersonItemsInShare;
  bool hideBreakdownInShare;

  ShareOptions({
    this.includeItemsInShare = true,
    this.includePersonItemsInShare = false,
    this.hideBreakdownInShare = false,
  });
}
