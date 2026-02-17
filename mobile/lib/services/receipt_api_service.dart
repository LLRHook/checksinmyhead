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
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';
import 'package:checks_frontend/services/receipt_parser.dart';

/// Service that sends receipt images to the backend for parsing via Anthropic Claude.
class ReceiptApiService {
  static const _timeout = Duration(seconds: 45);
  static final _logger = Logger();

  String get _baseUrl {
    if (kReleaseMode) {
      return 'https://billington-api.onrender.com';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Sends a receipt image to the backend for parsing.
  ///
  /// Returns a [ParsedReceipt] on success, or throws a [ReceiptParseException].
  Future<ParsedReceipt> parseReceipt(String imagePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/receipts/parse'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ParsedReceipt.fromJson(data);
      }

      // Parse error message from backend response
      String serverMessage = '';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = body['error'] as String? ?? '';
      } catch (_) {}

      _logger.d('Receipt parse failed: ${response.statusCode} ${response.body}');

      switch (response.statusCode) {
        case 429:
          throw ReceiptParseException(
            serverMessage.isNotEmpty ? serverMessage : 'Too many scans. Please wait a moment and try again.',
            isRateLimit: true,
          );
        case 413:
          throw ReceiptParseException(
            serverMessage.isNotEmpty ? serverMessage : 'Image is too large. Try a lower resolution photo.',
          );
        case 503:
          throw ReceiptParseException(
            serverMessage.isNotEmpty ? serverMessage : 'Scanner is temporarily unavailable. Please try again later.',
          );
        case 422:
          throw ReceiptParseException(
            serverMessage.isNotEmpty ? serverMessage : 'Could not read the receipt. Try a clearer photo.',
          );
        default:
          throw ReceiptParseException(
            serverMessage.isNotEmpty ? serverMessage : 'Something went wrong (${response.statusCode}). Please try again.',
          );
      }
    } on ReceiptParseException {
      rethrow;
    } on TimeoutException {
      throw ReceiptParseException(
        'Request timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw ReceiptParseException(
        'Could not connect to server. Check your connection.',
      );
    } catch (e) {
      _logger.d('Receipt parse error: $e');
      throw ReceiptParseException(
        'Could not connect to server. Check your connection.',
      );
    }
  }
}

/// Exception thrown when receipt parsing fails.
class ReceiptParseException implements Exception {
  final String message;
  final bool isRateLimit;

  ReceiptParseException(this.message, {this.isRateLimit = false});

  @override
  String toString() => message;
}
