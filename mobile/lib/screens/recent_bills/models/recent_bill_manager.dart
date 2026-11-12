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

enum _AttachmentRecovery { absent, attached, unresolved, checkpointFailed }

class RecentBillsManager extends ChangeNotifier {
  static final RecentBillsManager _instance = RecentBillsManager._internal();

  factory RecentBillsManager() => _instance;

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

  Future<List<RecentBillModel>> getRecentBills({
    bool requireComplete = false,
  }) async {
    try {
      final recentBillsData = await _db.getRecentBills();
      final bills = recentBillsData.map(RecentBillModel.fromData).toList();

      return bills;
    } catch (_) {
      debugPrint('Error fetching bills');
      if (requireComplete) rethrow;
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
    List<dynamic> remoteBills, {
    int? localTabId,
  }) => _db.transaction(() async {
    final localIds = <int>[];
    var localBills = await _db.getRecentBills();
    final protectedIds = <int>{};
    final remoteIds = <int>{};
    for (final raw in remoteBills) {
      if (raw is! Map<String, dynamic> ||
          raw['id'] is! int ||
          (raw['id'] as int) <= 0 ||
          !remoteIds.add(raw['id'] as int)) {
        throw const FormatException('Incomplete remote receipt list');
      }
      final id = raw['id'] as int;
      final existing = _findLocalCopy(
        localBills,
        id,
        _remoteTabBillMarker(tabId, id),
      );
      if (existing != null) protectedIds.add(existing.id);
    }

    for (final raw in remoteBills) {
      final rawBill = raw as Map<String, dynamic>;
      final remoteBillId = rawBill['id'] as int;

      final marker = _remoteTabBillMarker(tabId, remoteBillId);
      final existing = _findLocalCopy(localBills, remoteBillId, marker);
      final localBillId = existing?.id;

      var people = _peopleFromRemoteBill(rawBill);
      if (existing?.receiptParticipants != null) {
        final original =
            (jsonDecode(existing!.receiptParticipants!) as List)
                .map((p) => Person.fromReceiptJson(p as Map<String, dynamic>))
                .toList();
        final mapping =
            existing.originalParticipantMap == null
                ? <Map<String, dynamic>>[]
                : (jsonDecode(existing.originalParticipantMap!) as List)
                    .cast<Map<String, dynamic>>();
        people =
            people.map((p) {
              final ref =
                  mapping
                      .where((m) => m['participant_id'] == p.participantId)
                      .firstOrNull?['client_ref'];
              final old =
                  original
                      .where(
                        (o) =>
                            ref != null
                                ? o.clientRef == ref
                                : p.participantId != null &&
                                    o.participantId == p.participantId,
                      )
                      .firstOrNull;
              return old == null
                  ? p
                  : Person(
                    name: p.name,
                    color: old.color,
                    clientRef: old.clientRef,
                    allocationLabel: old.allocationLabel,
                    participantId: p.participantId,
                    memberId: p.memberId,
                  );
            }).toList();
      }
      final peopleByName = {
        for (final person in people)
          person.participantId != null
                  ? 'id:${person.participantId}'
                  : person.name:
              person,
      };
      final items = _itemsFromRemoteBill(rawBill, peopleByName);
      final shares = _sharesFromRemoteBill(rawBill, peopleByName);
      final savedShareRows =
          rawBill['identity_version'] == 2
              ? [
                for (final e in shares.entries)
                  {
                    'client_ref': e.key.clientRef,
                    'name': e.key.name,
                    'total': e.value,
                  },
              ]
              : [
                for (final raw
                    in (rawBill['person_shares'] as List? ?? [])
                        .whereType<Map<String, dynamic>>())
                  {
                    'recorded_share_id': raw['id'],
                    'name': raw['person_name'] ?? '',
                    'total': raw['total'],
                    if (raw.containsKey('paid')) 'paid': raw['paid'],
                  },
              ];

      if (existing?.creationHandle != null) {
        // Authorized tab refresh is a current share projection. It cannot replace
        // original content, source credentials, or the immutable create snapshot.
        await _db.checkpointReceipt(
          existing!.id,
          RecentBillsCompanion(
            receiptParticipants: Value(
              jsonEncode(people.map((p) => p.toReceiptJson()).toList()),
            ),
            currentIdentityRevision: Value(
              rawBill['identity_revision'] as int?,
            ),
            currentIdentityState: Value(rawBill['identity_state'] as String?),
            currentGraph: Value(jsonEncode(rawBill)),
            savedShares: Value(jsonEncode(savedShareRows)),
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
        protectedReceiptIds: protectedIds,
      );
      final remoteUSD = (rawBill['usd_total'] as num?)?.toDouble();
      await _db.checkpointReceipt(
        importedId,
        RecentBillsCompanion(
          publicationState: const Value('imported'),
          currentIdentityRevision: Value(rawBill['identity_revision'] as int?),
          currentIdentityState: Value(rawBill['identity_state'] as String?),
          currentGraph: Value(jsonEncode(rawBill)),
          remoteBillId: Value(remoteBillId),
          authoritativeUsdTotal: Value(
            remoteUSD != null && remoteUSD.isFinite && remoteUSD >= 0
                ? remoteUSD
                : null,
          ),
          savedShares: Value(jsonEncode(savedShareRows)),
        ),
      );
      localIds.add(importedId);
      protectedIds.add(importedId);
      localBills = await _db.getRecentBills();
    }

    if (localTabId != null) {
      final tab = await _db.getTabById(localTabId);
      if (tab == null || tab.backendId != tabId) {
        throw StateError('Import destination unavailable');
      }
      await _db.updateTab(
        localTabId,
        TabsCompanion(billIds: Value(localIds.join(','))),
      );
    }
    return localIds;
  });

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
    final rows = bill['participants'];
    if (bill['identity_version'] == 2 && rows is List) {
      return rows
          .whereType<Map<String, dynamic>>()
          .map(
            (p) => Person(
              name: p['label'] as String? ?? '',
              allocationLabel:
                  (bill['person_shares'] as List? ?? [])
                          .whereType<Map<String, dynamic>>()
                          .where(
                            (s) => s['participant_id'] == p['participant_id'],
                          )
                          .firstOrNull?['person_name']
                      as String? ??
                  p['label'] as String? ??
                  '',
              color: Colors.blue,
              clientRef: 'remote_${bill['id']}_${p['participant_id']}',
              participantId: p['participant_id'] as int?,
              memberId:
                  p['binding_state'] == 'confirmed'
                      ? p['member_id'] as int?
                      : null,
            ),
          )
          .toList();
    }
    // Raw legacy names remain a presentation-only registry, never binding proof.
    final names = <String>[];
    for (final p in rows is List ? rows : []) {
      if (p is Map && p['name'] is String) names.add(p['name'] as String);
    }
    for (final p
        in bill['person_shares'] is List ? bill['person_shares'] : []) {
      if (p is Map &&
          p['person_name'] is String &&
          !names.contains(p['person_name'])) {
        names.add(p['person_name'] as String);
      }
    }
    return [
      for (var i = 0; i < names.length; i++)
        Person(
          name: names[i],
          color: Colors.blue,
          clientRef: 'legacy_${bill['id']}_$i',
        ),
    ];
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
          final person =
              assignment['participant_id'] is int
                  ? peopleByName['id:${assignment['participant_id']}']
                  : name == null
                  ? null
                  : peopleByName[name];
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
      final person =
          share['participant_id'] is int
              ? peopleByName['id:${share['participant_id']}']
              : name == null
              ? null
              : peopleByName[name];
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
    } catch (_) {
      debugPrint('Error deleting bill');
    }
  }

  Future<void> clearAllBills() async {
    try {
      await _db.clearAllBills();

      await getRecentBills();
      notifyListeners();
    } catch (_) {
      debugPrint('Error deleting all bills');
    }
  }

  Future<void> updateBillShareUrl(int id, String shareUrl) async {
    try {
      await _db.updateBillShareUrl(id, shareUrl);
      await getRecentBills();
      notifyListeners();
    } catch (_) {
      debugPrint('Error updating bill share URL');
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
          identityVersion: 2,
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
                          e.key.clientRef: e.value,
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
          snapshotVersion: const Value(2),
          creationWireVersion: const Value(2),
          receiptParticipants: Value(
            jsonEncode(
              receipt.participants.map((p) => p.toReceiptJson()).toList(),
            ),
          ),
          publicationState: const Value('pending'),
          valuationState: Value(
            receipt.currencyCode == 'USD' ? 'native' : 'pending',
          ),
          intendedTabId: Value(intendedTabId),
          attachmentState: Value(intendedTabId == null ? 'none' : 'pending'),
          receiptMetadata: Value(
            jsonEncode({
              'representation_version': 2,
              'is_custom_tip_amount': receipt.isCustomTipAmount,
              'birthday_name': receipt.birthdayPerson?.name,
              'birthday_ref': receipt.birthdayPerson?.clientRef,
            }),
          ),
          savedShares: Value(
            jsonEncode([
              for (final e in receipt.personShares.entries)
                {
                  'client_ref': e.key.clientRef,
                  'name': e.key.name,
                  'total': e.value,
                },
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
    var row = await _db.getBillById(localId);
    if (row == null) throw StateError('Saved receipt missing');
    final handle = row.creationHandle ?? 'history:$localId';
    final current = _inFlight[handle];
    if (intendedTabId != null) {
      row = await _rememberDestination(localId, intendedTabId);
      if (row.intendedTabId != intendedTabId) {
        return _result(
          localId,
          checkpointFailure: SaveFailure.attachmentUnknown,
        );
      }
    }
    final savedRow = row;
    final result =
        await (current ??
            _coordinate(handle, () async => _resumeCommitted(savedRow)));
    // An older pass may have already read "no destination". Continue only its
    // acknowledged publication: a failed create or attachment is never retried
    // automatically by joining this newly recorded intent.
    if (intendedTabId != null &&
        result.publication == PublicationState.published &&
        result.attachment != AttachmentState.attached &&
        result.failure == null) {
      return _coordinate(handle, () async {
        final latest = await _db.getBillById(localId);
        if (latest == null) throw StateError('Saved receipt missing');
        if (latest.publicationState != 'published') return _result(localId);
        return _resumeCommitted(latest);
      });
    }
    return result;
  }

  Future<RecentBill> _rememberDestination(int localId, int tabId) =>
      _db.transaction(() async {
        final row = await _db.getBillById(localId);
        if (row == null) throw StateError('Saved receipt missing');
        if (row.intendedTabId != null) return row;
        await _db.checkpointReceipt(
          localId,
          RecentBillsCompanion(
            intendedTabId: Value(tabId),
            attachmentState: const Value('pending'),
          ),
        );
        return (await _db.getBillById(localId))!;
      });

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
      row = await _rememberDestination(row.id, intendedTabId);
      if (row.intendedTabId != intendedTabId) {
        return _result(
          row.id,
          checkpointFailure: SaveFailure.attachmentUnknown,
        );
      }
    }
    if (row.creationHandle == null) {
      // A valid existing source link can attach, but history/import content is
      // never reconstructed into a new publication request.
      if (row.intendedTabId != null &&
          row.shareUrl?.startsWith('https://') == true) {
        return _attach(row);
      }
      _guardRawHistory(row);
      return _result(row.id);
    }
    if (!{1, 2}.contains(row.snapshotVersion) ||
        (row.snapshotVersion == 2 && row.creationWireVersion != 2) ||
        (row.snapshotVersion == 1 &&
            row.creationWireVersion != null &&
            row.creationWireVersion != 1)) {
      return _pending(row, SaveFailure.snapshotReview, blocked: true);
    }
    if (row.publicationState == 'published') return _attach(row);
    if (row.creationSnapshot == null || row.keyLocator == null) {
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
        identityVersion: row.creationWireVersion ?? 1,
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
          creationResponseVersion: Value(response.responseVersion),
          originalParticipantMap: Value(
            response.participantMap == null
                ? null
                : jsonEncode(response.participantMap),
          ),
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
    Future<_AttachmentRecovery> reconcile() async {
      try {
        final data = await _api.getTabData(tab!.backendId!, tab.accessToken!);
        final bills = data['bills'];
        if (bills is List &&
            bills.any((b) => b is Map && b['id'] == remoteId)) {
          // The read establishes the no-op postcondition, not source authority.
          // Reauthorize source, destination and member at the maintained attach
          // boundary even after finalization before recording local completion.
          int? revision;
          if (row.creationWireVersion == 2) {
            final current = await _api.getSharedBill('$remoteId', billToken);
            revision = current['identity_revision'] as int?;
            if (revision == null) return _AttachmentRecovery.unresolved;
          }
          await _api.addBillToTab(
            tab.backendId!,
            remoteId,
            tab.accessToken!,
            billToken: billToken,
            memberToken: tab.memberToken,
            expectedRevision: revision,
          );
          try {
            await _db.checkpointAttachment(row.id, tabId);
          } catch (_) {
            return _AttachmentRecovery.checkpointFailed;
          }
          return _AttachmentRecovery.attached;
        }
        return bills is List
            ? _AttachmentRecovery.absent
            : _AttachmentRecovery.unresolved;
      } catch (_) {
        // Known association/read uncertainty is terminal for this explicit pass.
        return _AttachmentRecovery.unresolved;
      }
    }

    Future<SaveReceiptResult> recoveryResult(_AttachmentRecovery result) =>
        result == _AttachmentRecovery.attached
            ? _result(row.id)
            : result == _AttachmentRecovery.checkpointFailed
            ? _result(row.id, checkpointFailure: SaveFailure.checkpointFailed)
            : _pending(row, SaveFailure.attachmentUnknown);

    // Read before any retry, even if a later finalization prevents new writes.
    if (row.attachmentState == 'attempted') {
      final observed = await reconcile();
      if (observed != _AttachmentRecovery.absent) {
        return recoveryResult(observed);
      }
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
      int? currentRevision;
      if (row.creationWireVersion == 2) {
        final current = await _api.getSharedBill('$remoteId', billToken);
        currentRevision = current['identity_revision'] as int?;
        if (currentRevision == null) {
          throw ApiException('Current identity revision unavailable');
        }
      }
      await _api.addBillToTab(
        tab.backendId!,
        remoteId,
        tab.accessToken!,
        billToken: billToken,
        expectedRevision: currentRevision,
        memberToken: tab.memberToken,
      );
    } catch (_) {
      return recoveryResult(await reconcile());
    }
    try {
      await _db.checkpointAttachment(row.id, tabId);
    } catch (_) {
      return _result(row.id, checkpointFailure: SaveFailure.checkpointFailed);
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
    } catch (_) {
      // Keep the operation diagnostic finite; never include driver parameters.
      debugPrint('Error updating bill name');
    }
  }
}
