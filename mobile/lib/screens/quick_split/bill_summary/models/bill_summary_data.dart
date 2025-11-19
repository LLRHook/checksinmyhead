// Billington: Privacy-first receipt spliting
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

// mobile/lib/screens/quick_split/bill_summary/models/bill_summary_data.dart
// mobile/lib/screens/quick_split/bill_summary/models/bill_summary_data.dart

import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';

/// Consolidated data model for bill summary
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
  
  // Payment method fields
  final String? paymentMethodName;    // e.g., "Venmo", "Zelle"
  final String? paymentMethodIdentifier; // e.g., "@username", "phone"

  BillSummaryData({
    required this.participants,
    required this.personShares,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    this.birthdayPerson,
    this.tipPercentage = 0,
    this.isCustomTipAmount = false,
    this.billName = '',
    this.paymentMethodName,
    this.paymentMethodIdentifier,
  });

  /// Creates a copy with updated fields
  BillSummaryData copyWith({
    List<Person>? participants,
    Map<Person, double>? personShares,
    List<BillItem>? items,
    double? subtotal,
    double? tax,
    double? tipAmount,
    double? total,
    Person? birthdayPerson,
    double? tipPercentage,
    bool? isCustomTipAmount,
    String? billName,
    String? paymentMethodName,
    String? paymentMethodIdentifier,
  }) {
    return BillSummaryData(
      participants: participants ?? this.participants,
      personShares: personShares ?? this.personShares,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      tipAmount: tipAmount ?? this.tipAmount,
      total: total ?? this.total,
      birthdayPerson: birthdayPerson ?? this.birthdayPerson,
      tipPercentage: tipPercentage ?? this.tipPercentage,
      isCustomTipAmount: isCustomTipAmount ?? this.isCustomTipAmount,
      billName: billName ?? this.billName,
      paymentMethodName: paymentMethodName ?? this.paymentMethodName,
      paymentMethodIdentifier: paymentMethodIdentifier ?? this.paymentMethodIdentifier,
    );
  }

  /// Returns participants sorted by total amount (highest to lowest)
  List<Person> get sortedParticipants {
    final sorted = List<Person>.from(participants);
    sorted.sort((a, b) {
      final aTotal = personShares[a] ?? 0;
      final bTotal = personShares[b] ?? 0;
      return bTotal.compareTo(aTotal); // Descending order
    });
    return sorted;
  }
}