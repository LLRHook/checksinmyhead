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
import 'dart:convert';
import 'dart:math';

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/services/receipt_validation.dart';
import 'package:checks_frontend/services/creation_key_store.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:drift/drift.dart' show Value;
import 'save_receipt_result.dart';
export 'save_receipt_result.dart';
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

  RecentBillsManager.withDependencies({
    required AppDatabase database,
    required ApiService api,
    CreationKeyStore? keyStore,
  }) : _database = database,
       _apiDependency = api,
       _keyDependency = keyStore;

  CreationKeyStore? _keyDependency;
  CreationKeyStore get _keys => _keyDependency ?? IOSCreationKeyStore();
  final _inFlight = <String, Future<SaveReceiptResult>>{};

  AppDatabase? _database;
  ApiService? _apiDependency;
  AppDatabase get _db => _database ?? DatabaseProvider.db;
  ApiService get _api => _apiDependency ??= ApiService();

  @override
  void dispose() {
    _billsStreamController.close();
    super.dispose();
  }

  Future<List<RecentBillModel>> getRecentBills() async {
    try {
      final recentBillsData = await _db.getRecentBills();
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

  Future<int> saveBill({
    int? billId,
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
    final id = await _db.saveBill(
      billId: billId,
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

    await _notifyCommitted();
    return id;
  }

  /// Caches tab bills received from the backend so a joined device can render
  /// the same trip dashboard as the device that added the receipt.
  Future<List<int>> importRemoteTabBills(
    int tabId,
    List<dynamic> remoteBills,
  ) async {
    final localIds = <int>[];
    var localBills = await _db.getRecentBills();

    for (final rawBill in remoteBills) {
      if (rawBill is! Map<String, dynamic>) continue;
      final remoteBillId = (rawBill['id'] as num?)?.toInt();
      if (remoteBillId == null || remoteBillId <= 0) continue;

      final marker = _remoteTabBillMarker(tabId, remoteBillId);
      final existing = _findLocalCopy(localBills, remoteBillId, marker);
      final localBillId = existing?.id;

      final people = _peopleFromRemoteBill(rawBill);
      final peopleByName = {
        for (final person in people) person.name.toLowerCase(): person,
      };
      final items = _itemsFromRemoteBill(rawBill, peopleByName);
      final shares = _sharesFromRemoteBill(rawBill, peopleByName);

      if (existing?.creationHandle != null) {
        // Authorized tab refresh is a current share projection. It cannot replace
        // original content, source credentials, or the immutable create snapshot.
        await _db.checkpointReceipt(
          existing!.id,
          RecentBillsCompanion(
            savedShares: Value(
              jsonEncode([
                for (final entry in shares.entries)
                  {'name': entry.key.name, 'total': entry.value},
              ]),
            ),
          ),
        );
        localIds.add(existing.id);
        continue;
      }
      final importedId = await _db.saveBill(
        billId: localBillId,
        participants: people,
        personShares: shares,
        items: items,
        subtotal: (rawBill['subtotal'] as num?)?.toDouble() ?? 0,
        tax: (rawBill['tax'] as num?)?.toDouble() ?? 0,
        tipAmount: (rawBill['tip_amount'] as num?)?.toDouble() ?? 0,
        tipPercentage: (rawBill['tip_percentage'] as num?)?.toDouble() ?? 0,
        total: (rawBill['total'] as num?)?.toDouble() ?? 0,
        billName: rawBill['name'] as String? ?? 'Trip receipt',
        shareUrl: existing?.shareUrl ?? marker,
        currencyCode: rawBill['currency_code'] as String? ?? 'USD',
        usdExchangeRate:
            (rawBill['usd_exchange_rate'] as num?)?.toDouble() ??
            (rawBill['currency_code'] == 'USD' ? 1 : 0),
        exchangeRateDate: rawBill['exchange_rate_date'] as String?,
        exchangeRateSource:
            rawBill['exchange_rate_source'] as String? ?? 'native-usd',
        skipDuplicateCheck: true,
      );
      final remoteUSD = (rawBill['usd_total'] as num?)?.toDouble();
      await _db.checkpointReceipt(
        importedId,
        RecentBillsCompanion(
          publicationState: const Value('imported'),
          remoteBillId: Value(remoteBillId),
          authoritativeUsdTotal: Value(
            remoteUSD != null && remoteUSD.isFinite && remoteUSD >= 0
                ? remoteUSD
                : null,
          ),
          savedShares: Value(
            jsonEncode([
              for (final entry in shares.entries)
                {'name': entry.key.name, 'total': entry.value},
            ]),
          ),
        ),
      );
      localIds.add(importedId);
      localBills = await _db.getRecentBills();
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
          uri.scheme == 'https' &&
          {'billington.app', 'billingtonapp.vercel.app'}.contains(uri.host) &&
          uri.queryParameters['t']?.isNotEmpty == true &&
          uri.pathSegments.length == 2 &&
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
      await _db.deleteBill(id);

      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting bill: $e');
    }
  }

  Future<void> clearAllBills() async {
    try {
      await _db.clearAllBills();

      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting all bills: $e');
    }
  }

  Future<void> updateBillShareUrl(int id, String shareUrl) async {
    try {
      await _db.updateBillShareUrl(id, shareUrl);
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating bill share URL: $e');
    }
  }

  /// Nonsecret operation identity, retained by the confirmation screen. The
  /// recovery capability itself is generated only by the native key store.
  static String newOperationHandle() {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<SaveReceiptResult> _coordinate(
    String handle,
    Future<SaveReceiptResult> Function() action,
  ) {
    final current = _inFlight[handle];
    if (current != null) return current;
    final future = Future<SaveReceiptResult>.sync(action);
    _inFlight[handle] = future;
    // Do not leave a failed future's cleanup as an unhandled asynchronous error.
    future.then<void>(
      (_) {
        _inFlight.remove(handle);
      },
      onError: (Object error, StackTrace stack) {
        _inFlight.remove(handle);
      },
    );
    return future;
  }

  Future<SaveReceiptResult> saveReceipt({
    required String operationHandle,
    required BillSummaryData receipt,
    bool lazyMode = false,
    String? displayCurrency,
    int? intendedTabId,
  }) => _coordinate(operationHandle, () async {
    if (operationHandle.isEmpty) {
      throw ArgumentError('A stable operation handle is required');
    }
    var row = await _db.getReceiptByHandle(operationHandle);
    if (row == null) {
      // Preflight raw assignments/names through the maintained actual builder.
      // Encode immediately: mutable callers/settings cannot change a retry.
      final snapshot = jsonEncode(
        _api.buildBillRequest(
          billName: receipt.billName,
          participants: lazyMode ? const [] : receipt.participants,
          personShares: lazyMode ? const {} : receipt.personShares,
          items: receipt.items,
          subtotal: receipt.subtotal,
          tax: receipt.tax,
          tipAmount: receipt.tipAmount,
          tipPercentage: receipt.tipPercentage,
          total: receipt.total,
          paymentMethods: receipt.paymentMethods,
          currencyCode: receipt.currencyCode,
          displayCurrency: displayCurrency,
          lazyMode: lazyMode,
        ),
      );
      final id = await _db.insertReceipt(
        RecentBillsCompanion(
          billName: Value(receipt.billName),
          participants: Value(
            jsonEncode(receipt.participants.map((p) => p.name).toList()),
          ),
          participantCount: Value(receipt.participants.length),
          total: Value(receipt.total),
          date: Value(DateTime.now().toIso8601String()),
          subtotal: Value(receipt.subtotal),
          tax: Value(receipt.tax),
          tipAmount: Value(receipt.tipAmount),
          tipPercentage: Value(receipt.tipPercentage),
          items: Value(
            jsonEncode(
              receipt.items
                  .map(
                    (i) => {
                      'name': i.name,
                      'price': i.price,
                      'assignments': {
                        for (final e in i.assignments.entries)
                          e.key.name: e.value,
                      },
                    },
                  )
                  .toList(),
            ),
          ),
          currencyCode: Value(receipt.currencyCode),
          usdExchangeRate: Value(receipt.currencyCode == 'USD' ? 1 : 0),
          exchangeRateSource: Value(
            receipt.currencyCode == 'USD' ? 'native-usd' : '',
          ),
          creationHandle: Value(operationHandle),
          keyLocator: Value('receipt-v1:$operationHandle'),
          creationSnapshot: Value(snapshot),
          snapshotVersion: const Value(1),
          publicationState: const Value('pending'),
          valuationState: Value(
            receipt.currencyCode == 'USD' ? 'native' : 'pending',
          ),
          intendedTabId: Value(intendedTabId),
          attachmentState: Value(intendedTabId == null ? 'none' : 'pending'),
          receiptMetadata: Value(
            jsonEncode({
              'is_custom_tip_amount': receipt.isCustomTipAmount,
              'birthday_name': receipt.birthdayPerson?.name,
            }),
          ),
          savedShares: Value(
            jsonEncode([
              for (final e in receipt.personShares.entries)
                {'name': e.key.name, 'total': e.value},
            ]),
          ),
        ),
      );
      try {
        row = (await _db.getBillById(id))!;
      } catch (_) {
        return SaveReceiptResult(
          localId: id,
          publication: PublicationState.pending,
          valuation:
              receipt.currencyCode == 'USD'
                  ? ValuationState.native
                  : ValuationState.pending,
          attachment:
              intendedTabId == null
                  ? AttachmentState.none
                  : AttachmentState.pending,
          failure: SaveFailure.checkpointFailed,
        );
      }
    }
    return _resumeCommitted(row, intendedTabId: intendedTabId);
  });

  Future<SaveReceiptResult> resumeReceipt(
    int localId, {
    int? intendedTabId,
  }) async {
    final row = await _db.getBillById(localId);
    if (row == null) throw StateError('Saved receipt missing');
    return _coordinate(
      row.creationHandle ?? 'history:$localId',
      () async => _resumeCommitted(row, intendedTabId: intendedTabId),
    );
  }

  Future<SaveReceiptResult> _resumeCommitted(
    RecentBill row, {
    int? intendedTabId,
  }) async {
    try {
      return await _resume(row, intendedTabId: intendedTabId);
    } on BillValidationException {
      rethrow;
    } catch (_) {
      try {
        return await _result(
          row.id,
          checkpointFailure: SaveFailure.checkpointFailed,
        );
      } catch (_) {
        return SaveReceiptResult.fromRow(
          row.copyWith(failureCode: const Value('checkpointFailed')),
        );
      }
    }
  }

  Future<SaveReceiptResult> _result(
    int id, {
    SaveFailure? checkpointFailure,
  }) async {
    final row = (await _db.getBillById(id))!;
    await _notifyCommitted();
    return SaveReceiptResult.fromRow(
      checkpointFailure == null
          ? row
          : row.copyWith(failureCode: Value(checkpointFailure.name)),
    );
  }

  Future<void> _notifyCommitted() async {
    // Observers are downstream of the transaction and cannot change its outcome.
    try {
      await getRecentBills();
      notifyListeners();
    } catch (_) {
      /* committed */
    }
  }

  Future<SaveReceiptResult> _pending(
    RecentBill row,
    SaveFailure failure, {
    bool blocked = false,
  }) async {
    try {
      await _db.checkpointReceipt(
        row.id,
        RecentBillsCompanion(
          failureCode: Value(failure.name),
          publicationState: Value(blocked ? 'blocked' : row.publicationState),
        ),
      );
    } catch (_) {
      return _result(row.id, checkpointFailure: SaveFailure.checkpointFailed);
    }
    return _result(row.id);
  }

  Future<SaveReceiptResult> _resume(
    RecentBill row, {
    int? intendedTabId,
  }) async {
    if (intendedTabId != null && row.intendedTabId != intendedTabId) {
      if (row.intendedTabId != null) {
        return _pending(row, SaveFailure.attachmentUnknown);
      }
      await _db.checkpointReceipt(
        row.id,
        RecentBillsCompanion(
          intendedTabId: Value(intendedTabId),
          attachmentState: const Value('pending'),
        ),
      );
      row = (await _db.getBillById(row.id))!;
    }
    if (row.creationHandle == null) {
      _guardRawHistory(row);
      // A valid existing source link can attach, but history/import content is
      // never reconstructed into a new publication request.
      if (row.intendedTabId != null &&
          row.shareUrl?.startsWith('https://') == true) {
        return _attach(row);
      }
      return _result(row.id);
    }
    if (row.publicationState == 'published') return _attach(row);
    if (row.snapshotVersion != 1 ||
        row.creationSnapshot == null ||
        row.keyLocator == null) {
      return _pending(row, SaveFailure.snapshotReview, blocked: true);
    }
    CreationKeyResult key;
    try {
      key = await _keys.read(row.keyLocator!);
      if (key.status == CreationKeyStatus.absent && !row.publicationAttempted) {
        key = await _keys.createIfAbsent(row.keyLocator!);
      }
    } catch (_) {
      return _pending(row, SaveFailure.keyError);
    }
    if (key.canonicalKey == null) {
      final failure = switch (key.status) {
        CreationKeyStatus.absent => SaveFailure.keyAbsent,
        CreationKeyStatus.locked => SaveFailure.keyLocked,
        CreationKeyStatus.unsupported => SaveFailure.unsupportedPlatform,
        _ => SaveFailure.keyError,
      };
      return _pending(
        row,
        failure,
        blocked:
            row.publicationAttempted && key.status == CreationKeyStatus.absent,
      );
    }
    try {
      if (!await _api.supportsCreationReplay()) {
        return _pending(row, SaveFailure.capabilityUnavailable);
      }
    } catch (_) {
      return _pending(row, SaveFailure.capabilityUnavailable);
    }
    // This MUST commit before HTTP, including the first request after a crash.
    try {
      await _db.checkpointReceipt(
        row.id,
        const RecentBillsCompanion(
          publicationAttempted: Value(true),
          failureCode: Value(null),
          publicationState: Value('pending'),
        ),
      );
    } catch (_) {
      return _result(row.id, checkpointFailure: SaveFailure.checkpointFailed);
    }
    BillUploadResponse response;
    try {
      response = await _api.publishSnapshot(
        row.creationSnapshot!,
        key.canonicalKey!,
      );
    } on InvalidCreationResponse {
      return _pending(row, SaveFailure.invalidResponse);
    } on ApiException catch (error) {
      return _pending(
        row,
        error.statusCode == 409
            ? SaveFailure.conflict
            : error.statusCode == 400
            ? SaveFailure.contentReview
            : SaveFailure.publicationUnavailable,
        blocked: error.statusCode == 409 || error.statusCode == 400,
      );
    } catch (_) {
      return _pending(row, SaveFailure.publicationUnavailable);
    }
    try {
      // One SQL update atomically checkpoints all authority to the exact local ID.
      await _db.checkpointReceipt(
        row.id,
        RecentBillsCompanion(
          remoteBillId: Value(response.billId),
          shareUrl: Value(response.shareUrl),
          usdExchangeRate: Value(response.exchangeRateQuote.usdRate),
          exchangeRateDate: Value(response.exchangeRateQuote.rateDate),
          exchangeRateSource: Value(response.exchangeRateQuote.source),
          authoritativeUsdTotal: Value(response.usdTotal),
          publicationState: const Value('published'),
          valuationState: const Value('frozen'),
          failureCode: const Value(null),
        ),
      );
    } catch (_) {
      return _result(row.id, checkpointFailure: SaveFailure.checkpointFailed);
    }
    return _attach((await _db.getBillById(row.id))!);
  }

  Future<SaveReceiptResult> _attach(RecentBill row) async {
    final tabId = row.intendedTabId;
    if (tabId == null || row.attachmentState == 'attached') {
      return _result(row.id);
    }
    final uri = row.shareUrl == null ? null : Uri.tryParse(row.shareUrl!);
    final remoteId =
        row.remoteBillId ??
        (uri?.pathSegments.length == 2 && uri?.pathSegments.first == 'b'
            ? int.tryParse(uri!.pathSegments.last)
            : null);
    final billToken = uri?.queryParameters['t'];
    final tab = await _db.getTabById(tabId);
    if (uri?.scheme != 'https' ||
        !{'billington.app', 'billingtonapp.vercel.app'}.contains(uri?.host) ||
        remoteId == null ||
        uri?.path != '/b/$remoteId' ||
        uri?.userInfo.isNotEmpty == true ||
        uri?.hasPort == true ||
        remoteId <= 0 ||
        billToken == null ||
        billToken.isEmpty ||
        tab?.backendId == null ||
        tab?.accessToken == null) {
      return _pending(row, SaveFailure.destinationUnavailable);
    }
    Future<bool> reconcile() async {
      try {
        final data = await _api.getTabData(tab!.backendId!, tab.accessToken!);
        final bills = data['bills'];
        if (bills is List &&
            bills.any((b) => b is Map && b['id'] == remoteId)) {
          await _db.checkpointAttachment(row.id, tabId);
          return true;
        }
      } catch (_) {
        /* A failed read proves nothing about the earlier POST. */
      }
      return false;
    }

    // Read before any retry, even if a later finalization prevents writes.
    if (row.attachmentState == 'attempted' && await reconcile()) {
      return _result(row.id);
    }
    if (tab!.finalized) return _pending(row, SaveFailure.attachmentUnknown);
    try {
      await _db.checkpointReceipt(
        row.id,
        const RecentBillsCompanion(attachmentState: Value('attempted')),
      );
    } catch (_) {
      return _result(row.id, checkpointFailure: SaveFailure.checkpointFailed);
    }
    try {
      await _api.addBillToTab(
        tab.backendId!,
        remoteId,
        tab.accessToken!,
        billToken: billToken,
        memberToken: tab.memberToken,
      );
      await _db.checkpointAttachment(row.id, tabId);
    } catch (_) {
      if (!await reconcile()) {
        return _pending(row, SaveFailure.attachmentUnknown);
      }
    }
    return _result(row.id);
  }

  void _guardRawHistory(RecentBill row) {
    final model = RecentBillModel.fromData(row);
    for (final item in model.items ?? <Map<String, dynamic>>[]) {
      final assignments = item['assignments'] as Map<String, dynamic>?;
      for (final percentage in assignments?.values ?? <Object?>[]) {
        final error = receiptAssignmentPercentageError(percentage);
        if (error != null) throw BillValidationException(error);
      }
    }
    for (final name in model.participantNames) {
      final error = receiptParticipantNameError(name);
      if (error != null) throw BillValidationException(error);
    }
  }

  Future<void> retryPendingUploads() async {
    // Bound one launch pass. Imported and ambiguous legacy rows never enter it.
    for (final row in (await _db.getPendingReceipts()).take(
      AppDatabase.maxRecentBills,
    )) {
      await resumeReceipt(row.id);
    }
  }

  Future<String?> retrySingleBillUpload(int billId) async {
    final result = await resumeReceipt(billId);
    if (result.publication == PublicationState.legacy ||
        result.publication == PublicationState.imported) {
      if (result.shareUrl?.startsWith('https://') == true) {
        return result.shareUrl;
      }
      throw BillValidationException(result.message);
    }
    if (result.shareUrl == null) throw ApiException(result.message);
    return result.shareUrl;
  }

  Future<void> updateBillName(int id, String newName) async {
    try {
      // Request update from the database provider
      await _db.updateBillName(id, newName);

      // Refresh the bills list to update listeners
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error updating bill name: $e');
    }
  }
}
