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
