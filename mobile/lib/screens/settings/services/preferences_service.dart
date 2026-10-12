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

import 'package:checks_frontend/screens/settings/models/payment_method.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _selectedPaymentsKey = 'selectedPayments';
  static const String _paymentPrefix = 'payment_';
  static const String _displayNameKey = 'display_name';
  static const String _autoAddSelfKey = 'auto_add_self';
  static const String _accentColorKey = 'accent_color';
  static const String _tabCurrencyPrefix = 'tab_currency_';
  static const String _showBillTotalsInUSDKey = 'show_bill_totals_in_usd';

  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_firstLaunchKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  Future<void> saveDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, name);
  }

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<bool> getAutoAddSelf() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoAddSelfKey) ?? true;
  }

  Future<void> setAutoAddSelf(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAddSelfKey, value);
  }

  Future<void> saveSelectedPaymentMethods(List<String> methods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedPaymentsKey, methods);
    } catch (e) {
      debugPrint('Failed to save selected payment settings: $e');
    }
  }

  Future<List<String>> getSelectedPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_selectedPaymentsKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<void> savePaymentIdentifier(String method, String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_paymentPrefix$method', identifier);
  }

  Future<String?> getPaymentIdentifier(String method) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_paymentPrefix$method');
  }

  Future<void> removePaymentMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_paymentPrefix$method');

    final selected = await getSelectedPaymentMethods();
    selected.remove(method);
    await saveSelectedPaymentMethods(selected);
  }

  Future<Map<String, String>> getAllPaymentIdentifiers() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> results = {};

    final selectedMethods = await getSelectedPaymentMethods();
    for (final method in selectedMethods) {
      final identifier = prefs.getString('$_paymentPrefix$method');
      if (identifier != null && identifier.isNotEmpty) {
        results[method] = identifier;
      }
    }

    return results;
  }

  Future<void> saveAllPaymentSettings({
    required List<String> selectedMethods,
    required Map<String, String> identifiers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(_selectedPaymentsKey, selectedMethods);
      for (final method in PaymentMethod.availablePaymentMethods) {
        await prefs.remove('$_paymentPrefix$method');
      }

      for (final entry in identifiers.entries) {
        if (selectedMethods.contains(entry.key)) {
          await prefs.setString('$_paymentPrefix${entry.key}', entry.value);
        }
      }
    } catch (e) {
      debugPrint('Failed to save all payment settings: $e');
    }
  }

  Future<int?> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey);
  }

  Future<void> setAccentColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, colorValue);
  }

  Future<void> resetAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accentColorKey);
  }

  Future<String> getTabDisplayCurrency(int tabId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_tabCurrencyPrefix$tabId') ?? 'USD';
  }

  Future<void> setTabDisplayCurrency(int tabId, String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_tabCurrencyPrefix$tabId',
      currencyCode.trim().toUpperCase(),
    );
  }

  Future<bool> getShowBillTotalsInUSD() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showBillTotalsInUSDKey) ?? false;
  }

  Future<void> setShowBillTotalsInUSD(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showBillTotalsInUSDKey, value);
  }
}
