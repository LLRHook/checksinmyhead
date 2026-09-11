// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/services/api_config.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/exchange_rate_quote.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isNetworkError;

  ApiException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 30);

  String get baseUrl => ApiConfig.baseUrl;

  Future<double> getCurrencyRate(String from, String to) async {
    final uri = Uri.parse(
      '$baseUrl/api/currency/rate?from=${from.toUpperCase()}&to=${to.toUpperCase()}',
    );
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(
        'Exchange rate unavailable',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (data['value'] as num?)?.toDouble();
    if (rate == null || rate <= 0) {
      throw ApiException('Invalid exchange rate response');
    }
    return rate;
  }

  /// Uploads a completed bill to the backend
  Future<BillUploadResponse> uploadBill({
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
    String currencyCode = 'USD',
    String? displayCurrency,
  }) async {
    try {
      // Build the request body matching backend's CreateBillRequest
      final requestBody = {
        'name': billName,
        'subtotal': subtotal,
        'tax': tax,
        'tip_amount': tipAmount,
        'tip_percentage': tipPercentage,
        'total': total,
        'participants': participants.map((p) => {'name': p.name}).toList(),
        'items': _buildItemsJson(items, participants),
        'person_shares': _buildPersonSharesJson(
          personShares,
          items,
          tax,
          tipAmount,
          total,
        ),
        'payment_methods': paymentMethods,
        'currency_code': currencyCode,
        'display_currency': displayCurrency ?? currencyCode,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/bills'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse bill upload response');
        }
        final result = BillUploadResponse.fromJson(data);
        if (!result.isAuthoritativeFor(currencyCode)) {
          throw ApiException(
            'The server did not confirm this daily conversion. Nothing was saved; retry or use USD.',
          );
        }
        return result;
      } else {
        throw ApiException(
          'Failed to upload bill',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  Future<ExchangeRateQuote> getExchangeRate(String currencyCode) async {
    final normalized = currencyCode.toUpperCase();
    if (normalized == 'USD') return const ExchangeRateQuote.usd();
    try {
      final response = await http
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
  }) {
    return {
      'name': billName,
      'subtotal': subtotal,
      'tax': tax,
      'tip_amount': tipAmount,
      'tip_percentage': tipPercentage,
      'total': total,
      'currency_code': currencyCode,
      'participants': participants.map((p) => {'name': p.name}).toList(),
      'items': _buildItemsJson(items, participants),
      'person_shares': _buildPersonSharesJson(
        personShares,
        items,
        tax,
        tipAmount,
        total,
      ),
      'payment_methods': paymentMethods,
    };
  }

  /// Builds the items JSON structure with assignments
  List<Map<String, dynamic>> _buildItemsJson(
    List<BillItem> items,
    List<Person> participants,
  ) {
    return items.map((item) {
      // Map person assignments using person names
      final assignments = <Map<String, dynamic>>[];

      item.assignments.forEach((person, percentage) {
        assignments.add({'person_name': person.name, 'percentage': percentage});
      });

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
    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'display_currency': displayCurrency,
      };
      if (creatorDisplayName != null && creatorDisplayName.isNotEmpty) {
        body['creator_display_name'] = creatorDisplayName;
      }

      final response = await http
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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
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
    };
    if (memberToken != null && memberToken.isNotEmpty) {
      headers['X-Member-Token'] = memberToken;
    }
    final response = await http
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
  Future<bool> addBillToTab(
    int tabId,
    int billId,
    String accessToken, {
    required String billToken,
    String? memberToken,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/tabs/$tabId/bills'),
            headers: headers,
            body: jsonEncode({'bill_id': billId, 'bill_token': billToken}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw ApiException(
          'Failed to add bill to tab',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Finalizes a tab, locking it from further edits and creating settlements
  Future<List<SettlementResponse>> finalizeTab(
    int tabId,
    String accessToken, {
    String? memberToken,
  }) async {
    try {
      final headers = <String, String>{'Authorization': 'Bearer $accessToken'};
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/tabs/$tabId/finalize'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Gets settlements for a finalized tab
  Future<List<SettlementResponse>> getSettlements(
    int tabId,
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tabs/$tabId/settlements'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map(
              (json) =>
                  SettlementResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException(
          'Failed to get settlements',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Toggles the paid status of a settlement
  Future<bool> updateSettlement(
    int tabId,
    int settlementId,
    String accessToken,
    bool paid,
  ) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/tabs/$tabId/settlements/$settlementId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'paid': paid}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw ApiException(
          'Failed to update settlement',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Joins a tab as a new member
  Future<TabJoinResponse> joinTab(
    int tabId,
    String accessToken,
    String displayName, {
    String? memberToken,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      if (memberToken != null && memberToken.isNotEmpty) {
        headers['X-Member-Token'] = memberToken;
      }
      final response = await http
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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  Future<void> leaveTab(
    int tabId,
    String accessToken,
    String memberToken,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/tabs/$tabId/members/me'),
            headers: {
              'Authorization': 'Bearer $accessToken',
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

  /// Gets members of a tab
  Future<List<TabMemberResponse>> getTabMembers(
    int tabId,
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tabs/$tabId/members'),
            headers: {'Authorization': 'Bearer $accessToken'},
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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Fetches full tab data from the backend
  Future<Map<String, dynamic>> getTabData(int tabId, String accessToken) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tabs/$tabId'),
            headers: {'Authorization': 'Bearer $accessToken'},
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
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Builds the person_shares JSON structure
  List<Map<String, dynamic>> _buildPersonSharesJson(
    Map<Person, double> personShares,
    List<BillItem> items,
    double tax,
    double tipAmount,
    double total,
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
        'person_name': person.name,
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

  BillUploadResponse({
    required this.billId,
    required this.accessToken,
    required this.shareUrl,
    this.exchangeRateQuote = const ExchangeRateQuote.usd(),
    this.usdTotal = 0,
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
    );
  }

  bool isAuthoritativeFor(String requestedCurrencyCode) {
    final requested = requestedCurrencyCode.trim().toUpperCase();
    if (requested.isEmpty || requested == 'USD') {
      return exchangeRateQuote.currencyCode == 'USD' &&
          exchangeRateQuote.usdRate == 1;
    }
    return exchangeRateQuote.currencyCode == requested &&
        exchangeRateQuote.isValid &&
        usdTotal.isFinite &&
        usdTotal > 0;
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
