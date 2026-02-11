// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:logger/web.dart';

class ApiService {
  // Dynamic base URL based on platform and build mode
  String get baseUrl {
    // Production mode
    if (kReleaseMode) {
      return 'https://api.billington.app';
    }

    // Development mode - Android emulator uses 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }

    // Development mode - iOS simulator uses localhost
    return 'http://localhost:8080';
  }

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
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return BillUploadResponse(
          billId: data['bill_id'],
          accessToken: data['access_token'],
          shareUrl: data['share_url'],
        );
      } else {
        logger.d('Failed to upload bill: ${response.statusCode}');
        logger.d('Response: ${response.body}');
        return null;
      }
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
  Future<TabCreateResponse?> createTab(String name, String description) async {
    var logger = Logger();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return TabCreateResponse(
          tabId: data['tab_id'],
          accessToken: data['access_token'],
          shareUrl: data['share_url'],
        );
      } else {
        logger.d('Failed to create tab: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logger.d('Error creating tab: $e');
      return null;
    }
  }

  /// Adds a bill to a tab on the backend
  /// Returns true if successful
  Future<bool> addBillToTab(int tabId, int billId, String accessToken) async {
    var logger = Logger();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tabs/$tabId/bills?t=$accessToken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bill_id': billId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        logger.d('Failed to add bill to tab: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logger.d('Error adding bill to tab: $e');
      return false;
    }
  }

  /// Uploads an image to a tab
  Future<TabImageResponse?> uploadTabImage(
    int tabId,
    String accessToken,
    File imageFile,
  ) async {
    var logger = Logger();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/tabs/$tabId/images?t=$accessToken'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return TabImageResponse.fromJson(data);
      } else {
        logger.d('Failed to upload image: ${response.statusCode}');
        return null;
      }
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
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TabImageResponse.fromJson(json)).toList();
      } else {
        logger.d('Failed to get images: ${response.statusCode}');
        return [];
      }
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
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.d('Error updating image: $e');
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
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.d('Error deleting image: $e');
      return false;
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
      final proportion = subtotalForPerson / (total - tax - tipAmount);
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

  TabCreateResponse({
    required this.tabId,
    required this.accessToken,
    required this.shareUrl,
  });
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
      id: json['id'],
      tabId: json['tab_id'],
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
