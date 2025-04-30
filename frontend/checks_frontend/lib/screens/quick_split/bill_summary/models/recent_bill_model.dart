// lib/models/recent_bill_model.dart
import 'dart:convert';
import 'package:checks_frontend/database/database.dart';
import 'package:flutter/material.dart';

class RecentBillModel {
  final int id;
  final List<String> participantNames;
  final int participantCount;
  final double total;
  final DateTime date;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final List<Map<String, dynamic>>? items;
  final Color color;

  RecentBillModel({
    required this.id,
    required this.participantNames,
    required this.participantCount,
    required this.total,
    required this.date,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    this.items,
    required this.color,
  });

  // Factory constructor to create a RecentBillModel from RecentBillData
  factory RecentBillModel.fromData(RecentBill data) {
    // Parse participant names from JSON
    List<String> names = [];
    try {
      final List<dynamic> decoded = jsonDecode(data.participants);
      names = decoded.cast<String>();
    } catch (e) {
      debugPrint('Error parsing participants: $e');
    }

    // Parse items if they exist
    List<Map<String, dynamic>>? itemsList;
    if (data.items != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data.items!);
        itemsList = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('Error parsing items: $e');
      }
    }

    // Parse date
    DateTime billDate;
    try {
      billDate = DateTime.parse(data.date);
    } catch (e) {
      billDate = data.createdAt; // Fallback to createdAt
    }

    return RecentBillModel(
      id: data.id,
      participantNames: names,
      participantCount: data.participantCount,
      total: data.total,
      date: billDate,
      subtotal: data.subtotal,
      tax: data.tax,
      tipAmount: data.tipAmount,
      items: itemsList,
      color: Color(data.colorValue),
    );
  }

  // Format date as a readable string
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Get first few participant names for display
  String get participantSummary {
    if (participantNames.isEmpty) return 'No participants';

    if (participantNames.length <= 2) {
      return participantNames.join(' & ');
    }

    return '${participantNames[0]}, ${participantNames[1]} & ${participantCount - 2} more';
  }
}
