// Spliq: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
  final String billName;

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
    this.billName = '',
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
