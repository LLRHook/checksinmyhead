// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/services/api_config.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:logger/web.dart';

class ApiService {
  static const _timeout = Duration(seconds: 30);

  String get baseUrl => ApiConfig.baseUrl;

  /// Uploads a completed bill to the backend
  /// Returns the share URL if successful, null if failed
  Future<BillUploadResponse?> uploadBill({
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
    var logger = Logger();
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
        if (data == null) return null;
        return BillUploadResponse(
          billId: data['bill_id'] as int? ?? 0,
          accessToken: data['access_token'] as String? ?? '',
          shareUrl: data['share_url'] as String? ?? '',
        );
      } else {
        logger.d('Failed to upload bill: ${response.statusCode}');
        logger.d('Response: ${response.body}');
        return null;
      }
    } on TimeoutException {
      logger.d('Upload bill timed out');
      return null;
    } catch (e) {
      logger.d('Error uploading bill: $e');
      return null;
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
  /// Returns TabCreateResponse if successful, null if failed
  Future<TabCreateResponse?> createTab(
    String name,
    String description, {
    String? creatorDisplayName,
  }) async {
    var logger = Logger();
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
        if (data == null) return null;
        return TabCreateResponse(
          tabId: data['tab_id'] as int? ?? 0,
          accessToken: data['access_token'] as String? ?? '',
          shareUrl: data['share_url'] as String? ?? '',
          memberToken: data['member_token'] as String?,
          memberId: data['member_id'] as int?,
        );
      } else {
        logger.d('Failed to create tab: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      logger.d('Create tab timed out');
      return null;
    } catch (e) {
      logger.d('Error creating tab: $e');
      return null;
    }
  }

  /// Adds a bill to a tab on the backend
  /// Returns true if successful
  Future<bool> addBillToTab(
    int tabId,
    int billId,
    String accessToken, {
    String? memberToken,
  }) async {
    var logger = Logger();
    try {
      var url = '$baseUrl/api/tabs/$tabId/bills?t=$accessToken';
      if (memberToken != null) url += '&m=$memberToken';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bill_id': billId}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        logger.d('Failed to add bill to tab: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      logger.d('Add bill to tab timed out');
      return false;
    } catch (e) {
      logger.d('Error adding bill to tab: $e');
      return false;
    }
  }

  /// Uploads an image to a tab
  Future<TabImageResponse?> uploadTabImage(
    int tabId,
    String accessToken,
    File imageFile, {
    String? memberToken,
  }) async {
    var logger = Logger();
    try {
      var url = '$baseUrl/api/tabs/$tabId/images?t=$accessToken';
      if (memberToken != null) url += '&m=$memberToken';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) return null;
        return TabImageResponse.fromJson(data);
      } else {
        logger.d('Failed to upload image: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      logger.d('Upload image timed out');
      return null;
    } catch (e) {
      logger.d('Error uploading image: $e');
      return null;
    }
  }

  /// Gets all images for a tab
  Future<List<TabImageResponse>> getTabImages(
    int tabId,
    String accessToken,
  ) async {
    var logger = Logger();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/images?t=$accessToken'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TabImageResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        logger.d('Failed to get images: ${response.statusCode}');
        return [];
      }
    } on TimeoutException {
      logger.d('Get images timed out');
      return [];
    } catch (e) {
      logger.d('Error getting images: $e');
      return [];
    }
  }

  /// Toggles the processed status of an image
  Future<bool> updateTabImage(
    int tabId,
    int imageId,
    String accessToken,
    bool processed,
  ) async {
    var logger = Logger();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/tabs/$tabId/images/$imageId?t=$accessToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'processed': processed}),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } on TimeoutException {
      logger.d('Update image timed out');
      return false;
    } catch (e) {
      logger.d('Error updating image: $e');
      return false;
    }
  }

  /// Finalizes a tab, locking it from further edits and creating settlements
  Future<List<SettlementResponse>> finalizeTab(
    int tabId,
    String accessToken, {
    String? memberToken,
  }) async {
    var logger = Logger();
    try {
      var url = '$baseUrl/api/tabs/$tabId/finalize?t=$accessToken';
      if (memberToken != null) url += '&m=$memberToken';

      final response = await http.post(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SettlementResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        logger.d(
          'Failed to finalize tab: ${response.statusCode} ${response.body}',
        );
        return [];
      }
    } on TimeoutException {
      logger.d('Finalize tab timed out');
      return [];
    } catch (e) {
      logger.d('Error finalizing tab: $e');
      return [];
    }
  }

  /// Gets settlements for a finalized tab
  Future<List<SettlementResponse>> getSettlements(
    int tabId,
    String accessToken,
  ) async {
    var logger = Logger();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/settlements?t=$accessToken'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SettlementResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        logger.d('Failed to get settlements: ${response.statusCode}');
        return [];
      }
    } on TimeoutException {
      logger.d('Get settlements timed out');
      return [];
    } catch (e) {
      logger.d('Error getting settlements: $e');
      return [];
    }
  }

  /// Toggles the paid status of a settlement
  Future<bool> updateSettlement(
    int tabId,
    int settlementId,
    String accessToken,
    bool paid,
  ) async {
    var logger = Logger();
    try {
      final response = await http.patch(
        Uri.parse(
          '$baseUrl/api/tabs/$tabId/settlements/$settlementId?t=$accessToken',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'paid': paid}),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } on TimeoutException {
      logger.d('Update settlement timed out');
      return false;
    } catch (e) {
      logger.d('Error updating settlement: $e');
      return false;
    }
  }

  /// Deletes an image from a tab
  Future<bool> deleteTabImage(
    int tabId,
    int imageId,
    String accessToken,
  ) async {
    var logger = Logger();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tabs/$tabId/images/$imageId?t=$accessToken'),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } on TimeoutException {
      logger.d('Delete image timed out');
      return false;
    } catch (e) {
      logger.d('Error deleting image: $e');
      return false;
    }
  }

  /// Joins a tab as a new member
  Future<TabJoinResponse?> joinTab(
    int tabId,
    String accessToken,
    String displayName,
  ) async {
    var logger = Logger();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs/$tabId/join?t=$accessToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'display_name': displayName}),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data == null) return null;
        return TabJoinResponse(
          memberId: data['member_id'] as int? ?? 0,
          memberToken: data['member_token'] as String? ?? '',
          displayName: data['display_name'] as String? ?? '',
          role: data['role'] as String? ?? 'member',
        );
      } else {
        logger.d('Failed to join tab: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      logger.d('Join tab timed out');
      return null;
    } catch (e) {
      logger.d('Error joining tab: $e');
      return null;
    }
  }

  /// Gets members of a tab
  Future<List<TabMemberResponse>> getTabMembers(
    int tabId,
    String accessToken,
  ) async {
    var logger = Logger();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId/members?t=$accessToken'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TabMemberResponse.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        logger.d('Failed to get members: ${response.statusCode}');
        return [];
      }
    } on TimeoutException {
      logger.d('Get members timed out');
      return [];
    } catch (e) {
      logger.d('Error getting members: $e');
      return [];
    }
  }

  /// Fetches full tab data from the backend
  Future<Map<String, dynamic>?> getTabData(
    int tabId,
    String accessToken,
  ) async {
    var logger = Logger();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tabs/$tabId?t=$accessToken'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      } else {
        logger.d('Failed to get tab data: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      logger.d('Get tab data timed out');
      return null;
    } catch (e) {
      logger.d('Error getting tab data: $e');
      return null;
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
