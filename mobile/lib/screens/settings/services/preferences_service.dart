// Checkmate: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/settings/models/payment_method.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class for handling app preferences storage
class PreferencesService {
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _selectedPaymentsKey = 'selectedPayments';
  static const String _paymentPrefix = 'payment_';

  /// Returns a singleton instance
  static final PreferencesService _instance = PreferencesService._internal();

  factory PreferencesService() {
    return _instance;
  }

  PreferencesService._internal();

  /// Checks if this is the first launch of the app
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_firstLaunchKey) ?? true;
    } catch (e) {
      // Assume first launch on error
      return true;
    }
  }

  /// Marks the onboarding as complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  /// Saves the list of selected payment methods
  Future<void> saveSelectedPaymentMethods(List<String> methods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedPaymentsKey, methods);
    } catch (e) {
      // Silently fail for now
    }
  }

  /// Gets the list of selected payment methods
  Future<List<String>> getSelectedPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_selectedPaymentsKey) ?? [];
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Saves the identifier for a payment method
  Future<void> savePaymentIdentifier(String method, String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_paymentPrefix$method', identifier);
  }

  /// Gets the identifier for a payment method
  Future<String?> getPaymentIdentifier(String method) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_paymentPrefix$method');
  }

  /// Removes a payment method identifier
  Future<void> removePaymentMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_paymentPrefix$method');

    // Also remove from selected list
    final selected = await getSelectedPaymentMethods();
    selected.remove(method);
    await saveSelectedPaymentMethods(selected);
  }

  /// Loads all configured payment identifiers for selected methods only
  Future<Map<String, String>> getAllPaymentIdentifiers() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> results = {};

    // Get currently selected methods
    final selectedMethods = await getSelectedPaymentMethods();

    // Only load identifiers for selected methods
    for (final method in selectedMethods) {
      final identifier = prefs.getString('$_paymentPrefix$method');
      if (identifier != null && identifier.isNotEmpty) {
        results[method] = identifier;
      }
    }

    return results;
  }

  /// Saves all payment settings at once
  Future<void> saveAllPaymentSettings({
    required List<String> selectedMethods,
    required Map<String, String> identifiers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save selected methods list
      await prefs.setStringList(_selectedPaymentsKey, selectedMethods);

      // First, remove all payment identifiers to ensure cleanup
      for (final method in PaymentMethod.availablePaymentMethods) {
        await prefs.remove('$_paymentPrefix$method');
      }

      // Then save only the identifiers for selected methods
      for (final entry in identifiers.entries) {
        if (selectedMethods.contains(entry.key)) {
          await prefs.setString('$_paymentPrefix${entry.key}', entry.value);
        }
      }
    } catch (e) {
      // Silently fail for now
    }
  }
}
