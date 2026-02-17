// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/services/api_config.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';

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
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/bills'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse bill upload response');
        }
        return BillUploadResponse(
          billId: data['bill_id'] as int? ?? 0,
          accessToken: data['access_token'] as String? ?? '',
          shareUrl: data['share_url'] as String? ?? '',
        );
      } else {
        throw ApiException(
          'Failed to upload bill',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
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
  }) async {
    try {
      final body = <String, dynamic>{'name': name, 'description': description};
      if (creatorDisplayName != null && creatorDisplayName.isNotEmpty) {
        body['creator_display_name'] = creatorDisplayName;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);

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
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Adds a bill to a tab on the backend
  Future<bool> addBillToTab(
    int tabId,
    int billId,
    String accessToken, {
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

      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs/$tabId/bills'),
        headers: headers,
        body: jsonEncode({'bill_id': billId}),
      ).timeout(_timeout);

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
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Uploads an image to a tab
  Future<TabImageResponse> uploadTabImage(
    int tabId,
    String accessToken,
    File imageFile, {
    String? memberToken,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/tabs/$tabId/images'),
      );
      request.headers['Authorization'] = 'Bearer $accessToken';
      if (memberToken != null) {
        request.headers['X-Member-Token'] = memberToken;
      }
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) {
          throw ApiException('Failed to parse image upload response');
        }
        return TabImageResponse.fromJson(data);
      } else {
        throw ApiException(
          'Failed to upload image',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Gets all images for a tab
  Future<List<TabImageResponse>> getTabImages(
    int tabId,
    String accessToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/images'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TabImageResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw ApiException(
          'Failed to get images',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Toggles the processed status of an image
  Future<bool> updateTabImage(
    int tabId,
    int imageId,
    String accessToken,
    bool processed,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/tabs/$tabId/images/$imageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'processed': processed}),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw ApiException(
          'Failed to update image',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
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
      final headers = <String, String>{
        'Authorization': 'Bearer $accessToken',
      };
      if (memberToken != null) {
        headers['X-Member-Token'] = memberToken;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs/$tabId/finalize'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SettlementResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw ApiException(
          'Failed to finalize tab',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/settlements'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SettlementResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw ApiException(
          'Failed to get settlements',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
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
      final response = await http.patch(
        Uri.parse('$baseUrl/api/tabs/$tabId/settlements/$settlementId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'paid': paid}),
      ).timeout(_timeout);
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
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Deletes an image from a tab
  Future<bool> deleteTabImage(
    int tabId,
    int imageId,
    String accessToken,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tabs/$tabId/images/$imageId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw ApiException(
          'Failed to delete image',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
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
    String displayName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs/$tabId/join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'display_name': displayName}),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
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
        throw ApiException(
          'Failed to join tab',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Gets members of a tab
  Future<List<TabMemberResponse>> getTabMembers(
    int tabId,
    String accessToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/members'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TabMemberResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw ApiException(
          'Failed to get members',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
    } on SocketException {
      throw ApiException('Could not connect to server.', isNetworkError: true);
    } catch (e) {
      throw ApiException('An unexpected error occurred.');
    }
  }

  /// Fetches full tab data from the backend
  Future<Map<String, dynamic>> getTabData(
    int tabId,
    String accessToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);

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
      throw ApiException('Request timed out. Check your connection.', isTimeout: true);
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
            'is_shared': item.assignments.length > 1,
          });
        }
      }

      // Calculate proportional tax and tip
      final denominator = total - tax - tipAmount;
      final proportion = denominator > 0 ? subtotalForPerson / denominator : 0.0;
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

  BillUploadResponse({
    required this.billId,
    required this.accessToken,
    required this.shareUrl,
  });
}

/// Response object for tab images
class TabImageResponse {
  final int id;
  final int tabId;
  final String filename;
  final String url;
  final int size;
  final String mimeType;
  final bool processed;
  final String uploadedBy;
  final String createdAt;

  TabImageResponse({
    required this.id,
    required this.tabId,
    required this.filename,
    required this.url,
    required this.size,
    required this.mimeType,
    required this.processed,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory TabImageResponse.fromJson(Map<String, dynamic> json) {
    return TabImageResponse(
      id: (json['id'] as int?) ?? 0,
      tabId: (json['tab_id'] as int?) ?? 0,
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] ?? 0,
      mimeType: json['mime_type'] ?? '',
      processed: json['processed'] ?? false,
      uploadedBy: json['uploaded_by'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
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
