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

import 'dart:async';

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'recent_bill_model.dart';

class RecentBillsManager extends ChangeNotifier {
  static final RecentBillsManager _instance = RecentBillsManager._internal();

  factory RecentBillsManager() => _instance;

  final _billsStreamController =
      StreamController<List<RecentBillModel>>.broadcast();

  Stream<List<RecentBillModel>> get billsStream =>
      _billsStreamController.stream;

  RecentBillsManager._internal();

  @override
  void dispose() {
    _billsStreamController.close();
    super.dispose();
  }

  Future<List<RecentBillModel>> getRecentBills() async {
    try {
      final recentBillsData = await DatabaseProvider.db.getRecentBills();
      final bills = recentBillsData.map(RecentBillModel.fromData).toList();

      if (!_billsStreamController.isClosed) {
        _billsStreamController.add(bills);
      }

      return bills;
    } catch (e) {
      debugPrint('Error fetching bills: $e');
      return [];
    }
  }

  Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    double tipPercentage = 0,
    required String billName,
    String? shareUrl,
    String currencyCode = 'USD',
    double usdExchangeRate = 1,
    String? exchangeRateDate,
    String exchangeRateSource = 'native-usd',
    bool skipDuplicateCheck = false,
  }) async {
    try {
      await DatabaseProvider.db.saveBill(
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tipAmount: tipAmount,
        total: total,
        tipPercentage: tipPercentage,
        billName: billName,
        shareUrl: shareUrl,
        currencyCode: currencyCode,
        usdExchangeRate: usdExchangeRate,
        exchangeRateDate: exchangeRateDate,
        exchangeRateSource: exchangeRateSource,
        skipDuplicateCheck: skipDuplicateCheck,
      );

      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving bill: $e');
    }
  }

  /// Caches tab bills received from the backend so a joined device can render
  /// the same trip dashboard as the device that added the receipt.
  Future<List<int>> importRemoteTabBills(
    int tabId,
    List<dynamic> remoteBills,
  ) async {
    final localIds = <int>[];
    var localBills = await DatabaseProvider.db.getRecentBills();

    for (final rawBill in remoteBills) {
      if (rawBill is! Map<String, dynamic>) continue;
      final remoteBillId = (rawBill['id'] as num?)?.toInt();
      if (remoteBillId == null || remoteBillId <= 0) continue;

      final marker = _remoteTabBillMarker(tabId, remoteBillId);
      final existing = _findLocalCopy(localBills, remoteBillId, marker);
      if (existing != null) {
        localIds.add(existing.id);
        continue;
      }

      final people = _peopleFromRemoteBill(rawBill);
      final peopleByName = {
        for (final person in people) person.name.toLowerCase(): person,
      };
      final items = _itemsFromRemoteBill(rawBill, peopleByName);
      final shares = _sharesFromRemoteBill(rawBill, peopleByName);

      await DatabaseProvider.db.saveBill(
        participants: people,
        personShares: shares,
        items: items,
        subtotal: (rawBill['subtotal'] as num?)?.toDouble() ?? 0,
        tax: (rawBill['tax'] as num?)?.toDouble() ?? 0,
        tipAmount: (rawBill['tip_amount'] as num?)?.toDouble() ?? 0,
        tipPercentage: (rawBill['tip_percentage'] as num?)?.toDouble() ?? 0,
        total: (rawBill['total'] as num?)?.toDouble() ?? 0,
        billName: rawBill['name'] as String? ?? 'Trip receipt',
        shareUrl: marker,
        currencyCode: rawBill['currency_code'] as String? ?? 'USD',
        usdExchangeRate:
            (rawBill['usd_exchange_rate'] as num?)?.toDouble() ?? 1,
        exchangeRateDate: rawBill['exchange_rate_date'] as String?,
        exchangeRateSource:
            rawBill['exchange_rate_source'] as String? ?? 'native-usd',
        skipDuplicateCheck: true,
      );
      localBills = await DatabaseProvider.db.getRecentBills();
      final imported = _findLocalCopy(localBills, remoteBillId, marker);
      if (imported != null) localIds.add(imported.id);
    }

    return localIds;
  }

  String _remoteTabBillMarker(int tabId, int billId) =>
      'billington://tab/$tabId/bill/$billId';

  RecentBill? _findLocalCopy(
    List<RecentBill> bills,
    int remoteBillId,
    String marker,
  ) {
    for (final bill in bills) {
      final url = bill.shareUrl;
      if (url == marker) return bill;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[uri.pathSegments.length - 2] == 'b' &&
          int.tryParse(uri.pathSegments.last) == remoteBillId) {
        return bill;
      }
    }
    return null;
  }

  List<Person> _peopleFromRemoteBill(Map<String, dynamic> bill) {
    final names = <String>{};
    final participants = bill['participants'];
    if (participants is List) {
      for (final participant in participants) {
        final name =
            participant is Map<String, dynamic>
                ? participant['name'] as String?
                : null;
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    }
    final shares = bill['person_shares'];
    if (shares is List) {
      for (final share in shares) {
        final name =
            share is Map<String, dynamic>
                ? share['person_name'] as String?
                : null;
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    }
    return names.map((name) => Person(name: name, color: Colors.blue)).toList();
  }

  List<BillItem> _itemsFromRemoteBill(
    Map<String, dynamic> bill,
    Map<String, Person> peopleByName,
  ) {
    final rawItems = bill['items'];
    if (rawItems is! List) return [];
    return rawItems.whereType<Map<String, dynamic>>().map((item) {
      final assignments = <Person, double>{};
      final rawAssignments = item['assignments'];
      if (rawAssignments is List) {
        for (final assignment
            in rawAssignments.whereType<Map<String, dynamic>>()) {
          final name = assignment['person_name'] as String?;
          final person = name == null ? null : peopleByName[name.toLowerCase()];
          final percentage = (assignment['percentage'] as num?)?.toDouble();
          if (person != null && percentage != null && percentage > 0) {
            assignments[person] = percentage;
          }
        }
      }
      return BillItem(
        name: item['name'] as String? ?? 'Item',
        price: (item['price'] as num?)?.toDouble() ?? 0,
        assignments: assignments,
      );
    }).toList();
  }

  Map<Person, double> _sharesFromRemoteBill(
    Map<String, dynamic> bill,
    Map<String, Person> peopleByName,
  ) {
    final result = <Person, double>{};
    final shares = bill['person_shares'];
    if (shares is! List) return result;
    for (final share in shares.whereType<Map<String, dynamic>>()) {
      final name = share['person_name'] as String?;
      final person = name == null ? null : peopleByName[name.toLowerCase()];
      final total = (share['total'] as num?)?.toDouble();
      if (person != null && total != null) result[person] = total;
    }
    return result;
  }

  Future<void> deleteBill(int id) async {
    try {
      await DatabaseProvider.db.deleteBill(id);

      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting bill: $e');
    }
  }

  Future<void> clearAllBills() async {
    try {
      await DatabaseProvider.db.clearAllBills();

      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting all bills: $e');
    }
  }

  Future<void> updateBillShareUrl(int id, String shareUrl) async {
    try {
      await DatabaseProvider.db.updateBillShareUrl(id, shareUrl);
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating bill share URL: $e');
    }
  }

  /// Uses a placeholder payment method when none are configured.
  Future<List<Map<String, String>>> _getPaymentMethods() async {
    final prefsService = PreferencesService();
    final selectedMethods = await prefsService.getSelectedPaymentMethods();
    final identifiers = await prefsService.getAllPaymentIdentifiers();
    final paymentMethods =
        selectedMethods.map((method) {
          return {'name': method, 'identifier': identifiers[method] ?? ''};
        }).toList();

    return paymentMethods.isNotEmpty
        ? paymentMethods
        : [
          {'name': 'Venmo', 'identifier': '@username'},
        ];
  }

  /// Retries uploading bills that don't have share URLs yet.
  /// Called silently on app launch and can be triggered manually.
  Future<void> retryPendingUploads() async {
    try {
      final pendingBills = await DatabaseProvider.db.getBillsWithoutShareUrl();
      if (pendingBills.isEmpty) return;

      final apiService = ApiService();
      final paymentMethods = await _getPaymentMethods();

      for (final bill in pendingBills) {
        try {
          await _uploadPendingBill(bill, apiService, paymentMethods);
        } catch (e) {
          debugPrint('Failed to retry upload for bill ${bill.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in retryPendingUploads: $e');
    }
  }

  /// Retries upload for a single bill by ID.
  /// Returns the share URL on success, null on failure.
  Future<String?> retrySingleBillUpload(int billId) async {
    try {
      final bill = await DatabaseProvider.db.getBillById(billId);
      if (bill == null || bill.shareUrl != null) return bill?.shareUrl;

      final apiService = ApiService();
      final paymentMethods = await _getPaymentMethods();
      return await _uploadPendingBill(bill, apiService, paymentMethods);
    } catch (e) {
      debugPrint('Failed to retry upload for bill $billId: $e');
      return null;
    }
  }

  Future<String> _uploadPendingBill(
    RecentBill bill,
    ApiService apiService,
    List<Map<String, String>> paymentMethods,
  ) async {
    final model = RecentBillModel.fromData(bill);
    final response = await apiService.uploadBill(
      billName: model.billName,
      participants: model.participants,
      personShares: model.generatePersonShares(),
      items: model.getBillItems(),
      subtotal: model.subtotal,
      tax: model.tax,
      tipAmount: model.tipAmount,
      tipPercentage: model.tipPercentage,
      total: model.total,
      paymentMethods: paymentMethods,
      currencyCode: model.currencyCode,
    );
    await updateBillShareUrl(bill.id, response.shareUrl);
    return response.shareUrl;
  }

  Future<void> updateBillName(int id, String newName) async {
    try {
      // Request update from the database provider
      await DatabaseProvider.db.updateBillName(id, newName);

      // Refresh the bills list to update listeners
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error updating bill name: $e');
    }
  }
}
