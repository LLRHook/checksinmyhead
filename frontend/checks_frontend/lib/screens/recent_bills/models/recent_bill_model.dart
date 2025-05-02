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
  final double tipPercentage; // Added field for tip percentage
  final List<Map<String, dynamic>>? items;
  final Color color;
  final Map<String, Map<String, double>>? itemAssignments;

  RecentBillModel({
    required this.id,
    required this.participantNames,
    required this.participantCount,
    required this.total,
    required this.date,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    this.tipPercentage = 0, // Default value
    this.items,
    required this.color,
    this.itemAssignments,
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

    List<Map<String, dynamic>>? itemsList;
    Map<String, Map<String, double>>? assignmentsMap;

    if (data.items != null) {
      try {
        final List<dynamic> decodedItems = jsonDecode(data.items!);
        itemsList = decodedItems.cast<Map<String, dynamic>>();

        // Extract assignments from items
        assignmentsMap = {};
        for (var item in itemsList) {
          final itemName = item['name'] as String? ?? 'Unknown Item';
          final assignments = item['assignments'] as Map<String, dynamic>?;

          if (assignments != null) {
            Map<String, double> personAssignments = {};

            assignments.forEach((personName, percentage) {
              if (percentage is num) {
                personAssignments[personName] = percentage.toDouble();
              }
            });

            if (personAssignments.isNotEmpty) {
              assignmentsMap[itemName] = personAssignments;
            }
          }
        }
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

    // Calculate tip percentage if not stored
    double tipPercentage = 0;
    if (data.tipPercentage != null) {
      // Use stored value if available
      tipPercentage = data.tipPercentage!;
    } else if (data.subtotal > 0) {
      // Calculate if not available
      tipPercentage = (data.tipAmount / data.subtotal) * 100;
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
      tipPercentage: tipPercentage,
      items: itemsList,
      itemAssignments: assignmentsMap,
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
