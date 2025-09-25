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

/// Represents a payment method with its name and identifier
class PaymentMethod {
  final String name;

  /// The user identifier for this payment method (e.g., "@username", "email@example.com")
  final String identifier;

  /// Creates a new payment method
  const PaymentMethod({required this.name, required this.identifier});

  /// Creates a payment method from JSON data
  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      name: json['name'] as String,
      identifier: json['identifier'] as String,
    );
  }

  /// Converts this payment method to JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'identifier': identifier};
  }

  /// Creates a copy of this payment method with some fields replaced
  PaymentMethod copyWith({String? name, String? identifier}) {
    return PaymentMethod(
      name: name ?? this.name,
      identifier: identifier ?? this.identifier,
    );
  }

  /// Payment method hint/placeholder text based on the method name
  static String hintTextFor(String methodName) {
    switch (methodName) {
      case 'Venmo':
        return '@username';
      case 'Cash App':
        return '\$cashtag';
      case 'Zelle':
        return 'Zelle phone number/email';
      case 'Apple Pay':
        return 'Phone number';
      default:
        return 'Enter identifier';
    }
  }

  /// List of available payment methods
  static List<String> availablePaymentMethods = [
    'Venmo',
    'Zelle',
    'Apple Pay',
    'Cash App',
  ];

  /// Returns if the method requires a phone number input
  static bool requiresPhoneNumber(String methodName) {
    return methodName == 'Zelle' || methodName == 'Apple Pay';
  }
}
