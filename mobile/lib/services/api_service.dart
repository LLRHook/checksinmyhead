// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:checks_frontend/services/receipt_validation.dart';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/services/api_config.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/exchange_rate_quote.dart';
import 'package:checks_frontend/models/participant_identity.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final bool isTimeout;
  final bool isNetworkError;

  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.isTimeout = false,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

/// Local content that must be corrected before publication, rather than retried.
class BillValidationException extends ApiException {
  BillValidationException(super.message);
}

class InvalidCreationResponse extends ApiException {
  InvalidCreationResponse()
    : super('The creation response could not be verified.');
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;
  final http.Client _client;
  final String? _baseUrl;
  static const _timeout = Duration(seconds: 30);

  String get baseUrl => _baseUrl ?? ApiConfig.baseUrl;

  Future<T> _withStandardErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (_) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  Future<Map<String, dynamic>> getSharedBill(
    String billId,
    String token,
  ) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/bills/$billId'),
          headers: identityHeaders(token),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(
        'Could not load this bill',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid bill response');
    }
    return data;
  }

  /// Attached reads authenticate the tab and member independently. A destination
  /// token is never retried against the standalone source route.
  Future<Map<String, dynamic>> getCurrentBill({
    required String billId,
    required String token,
    String? tabId,
    String? memberToken,
  }) => _withStandardErrors(() async {
    var graph = await identityRequest(
      'GET',
      tabId == null ? '/api/bills/$billId' : '/api/tabs/$tabId',
      token,
      memberToken: memberToken,
    );
    if (tabId != null) {
      if (graph['id'] != int.tryParse(tabId) || graph['bills'] is! List) {
        throw ApiException('Current tab response could not be verified.');
      }
      final matches =
          (graph['bills'] as List)
              .whereType<Map<String, dynamic>>()
              .where((bill) => bill['id'] == int.tryParse(billId))
              .toList();
      if (matches.length != 1) {
        throw ApiException('This receipt is unavailable in the current tab.');
      }
      graph = matches.single;
    }
    if (graph['id'] != int.tryParse(billId) ||
        graph['items'] is! List ||
        graph['person_shares'] is! List) {
      throw ApiException('Current receipt response could not be verified.');
    }
    BillIdentity.fromJson(graph);
    return graph;
  });

  /// Null is a committed attached ACK, never a bill graph. The caller must read
  /// current state before offering payment review, without repeating the PATCH.
  Future<Map<String, dynamic>?> updateLazyBillItemAssignments({
    required String billId,
    required String token,
    required List<Map<String, dynamic>> updates,
    required int expectedRevision,
    String? tabId,
    String? memberToken,
  }) async {
    final response = await _client
        .patch(
          Uri.parse(
            tabId == null
                ? '$baseUrl/api/bills/$billId/assignments'
                : '$baseUrl/api/tabs/$tabId/bills/$billId/assignments',
          ),
          headers: identityHeaders(token, memberToken),
          body: jsonEncode({
            'updates': updates,
            'expected_revision': expectedRevision,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode == 409
            ? 'Someone changed the item selection. Refresh and try again.'
            : 'Could not save item selection',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid bill response');
    }
    if (tabId != null) {
      if (data['status'] != 'ok') {
        throw ApiException('Invalid claim acknowledgement');
      }
      return null;
    }
    if (data['id'] != int.tryParse(billId) ||
        data['items'] is! List ||
        data['person_shares'] is! List) {
      throw ApiException('Invalid bill response');
    }
    BillIdentity.fromJson(data);
    return data;
  }

  Future<void> updateSharedBillPaid({
    required String billId,
    required int shareId,
    required String token,
    required bool paid,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/api/bills/$billId/shares/$shareId'),
          headers: {
            'Content-Type': 'application/json',
            'X-Billington-Identity-Version': '2',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'paid': paid}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Could not update payment status');
    }
  }

  Future<void> updateTabBillPaid({
    required String tabId,
    required String billId,
    required int shareId,
    required String token,
    required String memberToken,
    required bool paid,
  }) async {
    await identityRequest(
      'PATCH',
      '/api/tabs/$tabId/bills/$billId/shares/$shareId/paid',
      token,
      memberToken: memberToken,
      body: {'paid': paid},
    );
  }

  Future<double> getCurrencyRate(String from, String to) =>
      _withStandardErrors(() async {
        final uri = Uri.parse('$baseUrl/api/currency/rate').replace(
          queryParameters: {'from': from.toUpperCase(), 'to': to.toUpperCase()},
        );
        final response = await _client.get(uri).timeout(_timeout);
        if (response.statusCode != 200) {
          throw ApiException(
            'Exchange rate unavailable',
            statusCode: response.statusCode,
          );
        }
        final data = jsonDecode(response.body);
        final value = data is Map ? data['rate'] : null;
        final rate = value is num ? value.toDouble() : null;
        if (rate == null || !rate.isFinite || rate <= 0) {
          throw ApiException('Invalid exchange rate response');
        }
        return rate;
      });

  /// Fail closed before any attempted create. Capability is a wire prerequisite,
  /// never evidence that replay-ignorant writers have been drained from a fleet.
  Future<bool> supportsCreationReplay() async {
    // Release source floors and old-writer drain are not qualified by this
    // source-only assignment. A capability response cannot enable a release.
    if (kReleaseMode) return false;
    return _withStandardErrors(() async {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/app/version-policy'))
          .timeout(_timeout);
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      final capability = body is Map ? body['capabilities'] : null;
      final replay =
          capability is Map ? capability['bill_creation_replay'] : null;
      return replay is Map &&
          replay['version'] == 1 &&
          replay['key_format'] == 'base64url-32';
    });
  }

  /// Exactly one POST of the persisted bytes; the owner controls durable attempt
  /// ordering and explicit later recovery. No fallback or automatic POST retry.
  Future<BillUploadResponse> publishSnapshot(
    String snapshot,
    String key, {
    int identityVersion = 1,
  }) => _withStandardErrors(() async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(key) ||
        base64Url.encode(base64Url.decode('$key=')).replaceAll('=', '') !=
            key) {
      throw BillValidationException('Invalid recovery key');
    }
    if (!{1, 2}.contains(identityVersion)) {
      throw BillValidationException('Unsupported saved wire version');
    }
    final request = jsonDecode(snapshot) as Map<String, dynamic>;
    final body = await _sendCreation(snapshot, key, identityVersion);
    const requiredFields = [
      'bill_id',
      'access_token',
      'share_url',
      'currency_code',
      'usd_exchange_rate',
      'exchange_rate_date',
      'exchange_rate_source',
      'usd_total',
    ];
    if (requiredFields.any((field) => !body.containsKey(field))) {
      throw InvalidCreationResponse();
    }
    if (body['bill_id'] is! int ||
        body['usd_exchange_rate'] is! num ||
        body['usd_total'] is! num ||
        [
          'access_token',
          'share_url',
          'currency_code',
          'exchange_rate_date',
          'exchange_rate_source',
        ].any((field) => body[field] is! String)) {
      throw InvalidCreationResponse();
    }
    if (identityVersion == 2) {
      final refs =
          (request['participants'] as List)
              .map((p) => p['client_ref'])
              .toList();
      final mapping = body['participant_map'];
      if (body['response_version'] != 2 ||
          body['identity_version'] != 2 ||
          body['identity_revision'] != 0 ||
          mapping is! List ||
          mapping.length != refs.length) {
        throw InvalidCreationResponse();
      }
      final ids = <int>{};
      for (var i = 0; i < refs.length; i++) {
        final row = mapping[i];
        if (row is! Map ||
            row.length != 2 ||
            row['client_ref'] != refs[i] ||
            row['participant_id'] is! int ||
            row['participant_id'] <= 0 ||
            !ids.add(row['participant_id'] as int)) {
          throw InvalidCreationResponse();
        }
      }
    } else if (identityVersion != 1 ||
        body.containsKey('participant_map') ||
        body.containsKey('response_version')) {
      throw InvalidCreationResponse();
    }
    final result = BillUploadResponse.fromJson(body);
    final nativeTotal = (request['total'] as num).toDouble();
    if (!result.isAuthoritativeFor(request['currency_code'] as String) ||
        result.billId <= 0 ||
        result.accessToken.isEmpty ||
        !result.hasValidSourceLink ||
        !result.hasFrozenProvenance ||
        !result.matchesNativeTotal(nativeTotal)) {
      throw InvalidCreationResponse();
    }
    return result;
  });

  Future<Map<String, dynamic>> _sendCreation(
    String snapshot,
    String key,
    int identityVersion,
  ) async {
    final abort = Completer<void>();
    final deadline = Timer(_timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request =
          http.AbortableRequest(
              'POST',
              Uri.parse('$baseUrl/api/bills'),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Idempotency-Key': key,
              if (identityVersion == 2) 'X-Billington-Identity-Version': '2',
            })
            ..body = snapshot;
      final response = await _client.send(request).timeout(_timeout);
      if (response.statusCode != 201) {
        await response.stream.listen(null).cancel();
        throw ApiException(
          'Publication pending',
          statusCode: response.statusCode,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 64 * 1024) {
          throw InvalidCreationResponse();
        }
        bytes.addAll(chunk);
      }
      final body = jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic>) throw InvalidCreationResponse();
      return body;
    } finally {
      deadline.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<ExchangeRateQuote> getExchangeRate(String currencyCode) async {
    final normalized = currencyCode.toUpperCase();
    if (normalized == 'USD') return const ExchangeRateQuote.usd();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/exchange-rates/$normalized'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          'Daily exchange rate unavailable. Retry or use USD.',
          statusCode: response.statusCode,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null) throw ApiException('Invalid exchange rate response.');
      final quote = ExchangeRateQuote.fromJson(data);
      if (!quote.isValid || quote.currencyCode != normalized) {
        throw ApiException('Invalid exchange rate response.');
      }
      return quote;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Daily exchange rate timed out. Retry or use USD.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException(
        'Could not load the daily rate. Retry or use USD.',
        isNetworkError: true,
      );
    } catch (_) {
      throw ApiException('Invalid exchange rate response.');
    }
  }

  Map<String, dynamic> buildBillRequest({
    required String billName,
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double tipPercentage,
    required double total,
    required List<Map<String, String>> paymentMethods,
    required String currencyCode,
    String? displayCurrency,
    bool lazyMode = false,
    int identityVersion = 1,
  }) {
    for (final person in [...participants, ...personShares.keys]) {
      final error = receiptParticipantNameError(
        person.name,
        allowEmpty: identityVersion == 2,
      );
      if (error != null) throw BillValidationException(error);
    }
    if (identityVersion == 2) {
      final refs = participants.map((p) => p.clientRef).toSet();
      if (refs.length != participants.length ||
          refs.any((r) => !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(r)) ||
          [
            ...personShares.keys,
            ...items.expand((i) => i.assignments.keys),
          ].any((p) => !refs.contains(p.clientRef))) {
        throw BillValidationException(
          'Review receipt participant references before sharing.',
        );
      }
    }
    return {
      'name': billName,
      'subtotal': subtotal,
      'tax': tax,
      'tip_amount': tipAmount,
      'tip_percentage': tipPercentage,
      'total': total,
      'currency_code': currencyCode,
      'display_currency': displayCurrency ?? currencyCode,
      'lazy_mode': lazyMode,
      'participants':
          participants
              .map(
                (p) => {
                  if (identityVersion == 2) 'client_ref': p.clientRef,
                  'name': p.name,
                },
              )
              .toList(),
      'items': _buildItemsJson(items, identityVersion),
      'person_shares': _buildPersonSharesJson(
        personShares,
        items,
        tax,
        tipAmount,
        total,
        identityVersion,
      ),
      'payment_methods': paymentMethods,
    };
  }

  List<Map<String, dynamic>> _buildItemsJson(
    List<BillItem> items,
    int identityVersion,
  ) {
    return items.map((item) {
      // Map person assignments using person names
      final assignments = <Map<String, dynamic>>[];

      item.assignments.forEach((person, percentage) {
        final percentageError = receiptAssignmentPercentageError(percentage);
        if (percentageError != null) {
          throw BillValidationException(percentageError);
        }
        final error = receiptParticipantNameError(
          person.name,
          allowEmpty: identityVersion == 2,
        );
        if (error != null) throw BillValidationException(error);
        // Zero means unassigned locally. Keep the person/share rows, but do not
        // send an assignment that the creation endpoint correctly rejects.
        if (percentage == 0) return;
        assignments.add({
          identityVersion == 2 ? 'participant_ref' : 'person_name':
              identityVersion == 2 ? person.clientRef : person.name,
          'percentage': percentage,
        });
      });
      if (item.assignments.values.fold(0.0, (sum, value) => sum + value) >
          100 + 1e-9) {
        throw BillValidationException(
          'Review item assignments: the percentages for an item cannot total '
          'more than 100 before sharing.',
        );
      }

      return {
        'name': item.name,
        'price': item.price,
        'assignments': assignments,
      };
    }).toList();
  }

  /// Creates a new tab on the backend
  Future<TabCreateResponse> createTab(
    String name,
    String description, {
    String? creatorDisplayName,
    String displayCurrency = 'USD',
  }) async {
    return _withStandardErrors(() async {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'display_currency': displayCurrency,
      };
      if (creatorDisplayName != null && creatorDisplayName.isNotEmpty) {
        body['creator_display_name'] = creatorDisplayName;
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tabs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse tab creation response');
        }
        return TabCreateResponse(
          tabId: data['tab_id'] as int? ?? 0,
          accessToken: data['access_token'] as String? ?? '',
          shareUrl: data['share_url'] as String? ?? '',
          memberToken: data['member_token'] as String?,
          memberId: data['member_id'] as int?,
        );
      } else {
        throw ApiException(
          'Failed to create tab',
          statusCode: response.statusCode,
        );
      }
    });
  }

  Future<void> updateTabDisplayCurrency(
    int tabId,
    String accessToken,
    String currencyCode, {
    String? memberToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Billington-Identity-Version': '2',
    };
    if (memberToken != null) {
      headers['X-Member-Token'] = memberToken;
    }
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/api/tabs/$tabId'),
          headers: headers,
          body: jsonEncode({'display_currency': currencyCode}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to update tab currency',
        statusCode: response.statusCode,
      );
    }
  }

  /// Adds a bill to a tab on the backend
  Future<void> addBillToTab(
    int tabId,
    int billId,
    String accessToken, {
    required String billToken,
    int? expectedRevision,
    String? memberToken,
  }) async {
    await _withStandardErrors(() async {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Billington-Identity-Version': '2',
      };
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }

      if (expectedRevision == null) {
        headers.remove('X-Billington-Identity-Version');
      }
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tabs/$tabId/bills'),
            headers: headers,
            body: jsonEncode({
              'bill_id': billId,
              'bill_token': billToken,
              if (expectedRevision != null)
                'expected_revision': expectedRevision,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to add bill to tab',
          statusCode: response.statusCode,
        );
      }
    });
  }

  /// Finalizes a tab, locking it from further edits and creating settlements
  Future<List<SettlementResponse>> finalizeTab(
    int tabId,
    String accessToken, {
    String? memberToken,
  }) async {
    return _withStandardErrors(() async {
      final headers = identityHeaders(accessToken);
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tabs/$tabId/finalize'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final envelope = jsonDecode(response.body);
        final List<dynamic> data = envelope['settlements'];
        return data
            .map(
              (json) =>
                  SettlementResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException(
          'Failed to finalize tab',
          statusCode: response.statusCode,
        );
      }
    });
  }

  /// Header2 history preserves review/unavailable separately from an empty array.
  Future<SettlementHistoryResponse> getSettlementHistory(
    int tabId,
    String token, {
    String? memberToken,
  }) async {
    final body = await identityRequest(
      'GET',
      '/api/tabs/$tabId/settlements',
      token,
      memberToken: memberToken,
    );
    final rows = body['settlements'];
    if (rows is! List ||
        body['identity_review_status'] is! String ||
        body['accounting_currency'] != 'USD') {
      throw ApiException('Recorded settlement history could not be verified.');
    }
    final parsed = <SettlementResponse>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! int ||
          row['id'] <= 0 ||
          row['tab_id'] != tabId ||
          row['amount'] is! num ||
          !(row['amount'] as num).isFinite ||
          row['paid'] is! bool ||
          row['person_name'] is! String) {
        throw ApiException(
          'Recorded settlement history could not be verified.',
        );
      }
      parsed.add(SettlementResponse.fromJson(row));
    }
    return SettlementHistoryResponse(
      parsed,
      body['identity_review_status'] as String,
    );
  }

  /// Toggles the paid status of a settlement
  Future<void> updateSettlement(
    int tabId,
    int settlementId,
    String accessToken,
    bool paid, {
    String? memberToken,
  }) async {
    await _withStandardErrors(() async {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Billington-Identity-Version': '2',
      };
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }
      final response = await _client
          .patch(
            Uri.parse('$baseUrl/api/tabs/$tabId/settlements/$settlementId'),
            headers: headers,
            body: jsonEncode({'paid': paid}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to update settlement',
          statusCode: response.statusCode,
        );
      }
    });
  }

  /// Joins a tab as a new member
  Future<TabJoinResponse> joinTab(
    int tabId,
    String accessToken,
    String displayName, {
    String? memberToken,
  }) async {
    return _withStandardErrors(() async {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Billington-Identity-Version': '2',
      };
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tabs/$tabId/join'),
            headers: headers,
            body: jsonEncode({'display_name': displayName}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse join tab response');
        }
        return TabJoinResponse(
          memberId: data['member_id'] as int? ?? 0,
          memberToken: data['member_token'] as String? ?? '',
          displayName: data['display_name'] as String? ?? '',
          role: data['role'] as String? ?? 'member',
        );
      } else {
        final message =
            response.statusCode == 403
                ? 'This invite is invalid or expired.'
                : response.statusCode == 404
                ? 'This tab no longer exists.'
                : 'Failed to join tab';
        throw ApiException(message, statusCode: response.statusCode);
      }
    });
  }

  Future<void> leaveTab(
    int tabId,
    String accessToken,
    String memberToken,
  ) async {
    await _withStandardErrors(() async {
      final response = await _client
          .delete(
            Uri.parse('$baseUrl/api/tabs/$tabId/members/me'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'X-Billington-Identity-Version': '2',
              'X-Member-Token': memberToken,
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode == 400
              ? 'The tab creator cannot leave the tab.'
              : 'Could not leave this tab.',
          statusCode: response.statusCode,
        );
      }
    });
  }

  /// Gets members of a tab
  Future<List<TabMemberResponse>> getTabMembers(
    int tabId,
    String accessToken,
  ) async {
    return _withStandardErrors(() async {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/tabs/$tabId/members'),
            headers: identityHeaders(accessToken),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map(
              (json) =>
                  TabMemberResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException(
          'Failed to get members',
          statusCode: response.statusCode,
        );
      }
    });
  }

  /// Fetches full tab data from the backend
  Future<Map<String, dynamic>> getTabData(int tabId, String accessToken) async {
    return _withStandardErrors(() async {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/tabs/$tabId'),
            headers: identityHeaders(accessToken),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse tab data response');
        }
        return data;
      } else {
        throw ApiException(
          'Failed to get tab data',
          statusCode: response.statusCode,
        );
      }
    });
  }

  static Map<String, String> identityHeaders(
    String token, [
    String? memberToken,
  ]) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'X-Billington-Identity-Version': '2',
    if (memberToken != null) 'X-Member-Token': memberToken,
  };

  Future<Map<String, dynamic>> identityRequest(
    String method,
    String path,
    String token, {
    String? memberToken,
    Map<String, dynamic>? body,
  }) => _withStandardErrors(() async {
    final request =
        http.Request(method, Uri.parse('$baseUrl$path'))
          ..headers.addAll(identityHeaders(token, memberToken))
          ..followRedirects = false;
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(_timeout),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      String? message;
      try {
        final body = jsonDecode(response.body) as Map;
        if (body['code'] is String) code = body['code'] as String;
        if (body['error'] is String) message = body['error'] as String;
      } catch (_) {}
      throw ApiException(
        response.statusCode == 409 && message != null && message.isNotEmpty
            ? message
            : response.statusCode == 409
            ? 'State changed or needs review. Refresh and deliberately retry.'
            : response.statusCode == 403
            ? 'Current membership or source proof was denied.'
            : 'Could not complete this identity action.',
        statusCode: response.statusCode,
        code: code,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  });

  Future<MemberIdentity> getCurrentMember(
    int tabId,
    String token,
    String memberToken,
  ) async => MemberIdentity.fromJson(
    await identityRequest(
      'GET',
      '/api/tabs/$tabId/members/me',
      token,
      memberToken: memberToken,
    ),
    tabId,
  );
  Future<MemberIdentity> renameCurrentMember(
    int tabId,
    String token,
    String memberToken,
    String label,
  ) async => MemberIdentity.fromJson(
    await identityRequest(
      'PATCH',
      '/api/tabs/$tabId/members/me',
      token,
      memberToken: memberToken,
      body: {'display_name': label},
    ),
    tabId,
  );
  Future<BillIdentity> getBillIdentity(String billId, String token) async =>
      BillIdentity.fromJson(await getSharedBill(billId, token));

  Future<ParticipantCommandResult> participantCommand({
    required String billId,
    required String token,
    required int expectedRevision,
    String? tabId,
    String? memberToken,
    int? participantId,
    String? clientRef,
    String? label,
    String? decision,
    int? requestRevision,
    int? memberId,
    String? billToken,
    bool bindingRequest = false,
  }) async {
    final root =
        tabId == null ? '/api/bills/$billId' : '/api/tabs/$tabId/bills/$billId';
    final suffix =
        bindingRequest
            ? '/binding-request'
            : decision != null
            ? '/binding'
            : '';
    final path =
        '$root/participants${participantId == null ? '' : '/$participantId'}$suffix';
    return ParticipantCommandResult.fromJson(
      await identityRequest(
        decision != null
            ? 'PUT'
            : bindingRequest || participantId == null
            ? 'POST'
            : 'PATCH',
        path,
        token,
        memberToken: memberToken,
        body: {
          'expected_revision': expectedRevision,
          if (clientRef != null) 'client_ref': clientRef,
          if (label != null) 'name': label,
          if (decision != null) 'decision': decision,
          if (requestRevision != null) 'request_revision': requestRevision,
          if (memberId != null) 'member_id': memberId,
          if (billToken != null &&
              tabId != null &&
              participantId != null &&
              !bindingRequest)
            'bill_token': billToken,
        },
      ),
    );
  }

  /// Builds the person_shares JSON structure
  List<Map<String, dynamic>> _buildPersonSharesJson(
    Map<Person, double> personShares,
    List<BillItem> items,
    double tax,
    double tipAmount,
    double total,
    int identityVersion,
  ) {
    final personSharesList = <Map<String, dynamic>>[];

    personShares.forEach((person, totalAmount) {
      // Calculate this person's share of items
      final personItems = <Map<String, dynamic>>[];
      double subtotalForPerson = 0;

      for (final item in items) {
        final percentage = item.assignments[person];
        if (percentage != null && percentage > 0) {
          final itemAmount = item.price * percentage / 100;
          subtotalForPerson += itemAmount;

          personItems.add({
            'name': item.name,
            'amount': itemAmount,
            'is_shared': percentage < 99.99,
          });
        }
      }

      // Calculate proportional tax and tip
      final denominator = total - tax - tipAmount;
      final proportion =
          denominator > 0 ? subtotalForPerson / denominator : 0.0;
      final taxShare = tax * proportion;
      final tipShare = tipAmount * proportion;

      personSharesList.add({
        identityVersion == 2 ? 'participant_ref' : 'person_name':
            identityVersion == 2 ? person.clientRef : person.name,
        'items': personItems,
        'subtotal': subtotalForPerson,
        'tax_share': taxShare,
        'tip_share': tipShare,
        'total': totalAmount,
      });
    });

    return personSharesList;
  }
}

/// Response object from tab creation
class TabCreateResponse {
  final int tabId;
  final String accessToken;
  final String shareUrl;
  final String? memberToken;
  final int? memberId;

  TabCreateResponse({
    required this.tabId,
    required this.accessToken,
    required this.shareUrl,
    this.memberToken,
    this.memberId,
  });
}

/// Response object from joining a tab
class TabJoinResponse {
  final int memberId;
  final String memberToken;
  final String displayName;
  final String role;

  TabJoinResponse({
    required this.memberId,
    required this.memberToken,
    required this.displayName,
    required this.role,
  });
}

/// Response object for tab members
class TabMemberResponse {
  final int id;
  final String displayName;
  final String role;
  final String joinedAt;

  TabMemberResponse({
    required this.id,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory TabMemberResponse.fromJson(Map<String, dynamic> json) {
    return TabMemberResponse(
      id: (json['id'] as int?) ?? 0,
      displayName: json['display_name'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] ?? '',
    );
  }
}

/// Response object from bill upload
class BillUploadResponse {
  final int billId;
  final String accessToken;
  final String shareUrl;
  final ExchangeRateQuote exchangeRateQuote;
  final double usdTotal;
  final int? responseVersion;
  final List<Map<String, dynamic>>? participantMap;

  BillUploadResponse({
    required this.billId,
    required this.accessToken,
    required this.shareUrl,
    this.exchangeRateQuote = const ExchangeRateQuote.usd(),
    this.usdTotal = 0,
    this.responseVersion,
    this.participantMap,
  });

  factory BillUploadResponse.fromJson(Map<String, dynamic> json) {
    final currencyCode = json['currency_code'] as String? ?? 'USD';
    final quote = ExchangeRateQuote(
      currencyCode: currencyCode,
      usdRate: (json['usd_exchange_rate'] as num?)?.toDouble() ?? 1,
      rateDate: json['exchange_rate_date'] as String? ?? '',
      source: json['exchange_rate_source'] as String? ?? 'native-usd',
    );
    return BillUploadResponse(
      billId: json['bill_id'] as int? ?? 0,
      accessToken: json['access_token'] as String? ?? '',
      shareUrl: json['share_url'] as String? ?? '',
      exchangeRateQuote: quote,
      usdTotal: (json['usd_total'] as num?)?.toDouble() ?? 0,
      responseVersion: json['response_version'] as int?,
      participantMap:
          (json['participant_map'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }

  bool get hasValidSourceLink {
    final uri = Uri.tryParse(shareUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        {'billington.app', 'billingtonapp.vercel.app'}.contains(uri.host) &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        uri.path == '/b/$billId' &&
        uri.queryParameters['t'] == accessToken;
  }

  bool get hasFrozenProvenance {
    if (exchangeRateQuote.currencyCode == 'USD') {
      return exchangeRateQuote.source == 'native-usd' &&
          exchangeRateQuote.rateDate.isEmpty;
    }
    final date = exchangeRateQuote.rateDate;
    final parsed = DateTime.tryParse(date);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
        parsed != null &&
        parsed.toIso8601String().startsWith('${date}T') &&
        exchangeRateQuote.source.isNotEmpty &&
        exchangeRateQuote.source != 'native-usd';
  }

  bool matchesNativeTotal(double nativeTotal) =>
      nativeTotal.isFinite &&
      usdTotal.isFinite &&
      (usdTotal - (nativeTotal * exchangeRateQuote.usdRate * 100).round() / 100)
              .abs() <
          0.000001;

  bool isAuthoritativeFor(String requestedCurrencyCode) {
    final requested = requestedCurrencyCode.trim().toUpperCase();
    if (requested.isEmpty || requested == 'USD') {
      return exchangeRateQuote.currencyCode == 'USD' &&
          exchangeRateQuote.usdRate == 1 &&
          usdTotal.isFinite &&
          usdTotal >= 0;
    }
    return exchangeRateQuote.currencyCode == requested &&
        exchangeRateQuote.isValid &&
        usdTotal.isFinite &&
        usdTotal >= 0;
  }
}

/// Response object for tab settlements
class SettlementResponse {
  final int id;
  final int tabId;
  final String personName;
  final double amount;
  final bool paid;
  final String createdAt;

  SettlementResponse({
    required this.id,
    required this.tabId,
    required this.personName,
    required this.amount,
    required this.paid,
    required this.createdAt,
  });

  factory SettlementResponse.fromJson(Map<String, dynamic> json) {
    return SettlementResponse(
      id: (json['id'] as int?) ?? 0,
      tabId: (json['tab_id'] as int?) ?? 0,
      personName: json['person_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paid: json['paid'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class SettlementHistoryResponse {
  final List<SettlementResponse> rows;
  final String reviewStatus;
  const SettlementHistoryResponse(this.rows, this.reviewStatus);
}
