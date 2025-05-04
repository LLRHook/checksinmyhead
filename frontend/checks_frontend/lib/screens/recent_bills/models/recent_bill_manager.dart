import 'dart:convert';
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'recent_bill_model.dart';

class RecentBillsManager {
  /// Get the recent bills from database
  static Future<List<RecentBillModel>> getRecentBills() async {
    try {
      final recentBillsData = await DatabaseProvider.db.getRecentBills();
      return recentBillsData.map(RecentBillModel.fromData).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save a bill to database
  static Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    Person? birthdayPerson,
    double tipPercentage = 0, // Add tipPercentage parameter with default value
    bool isCustomTipAmount =
        false, // Add isCustomTipAmount parameter with default value
  }) async {
    try {
      await DatabaseProvider.db.saveBill(
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tipAmount: tipAmount,
        total: total,
        tipPercentage: tipPercentage, // Pass the tipPercentage to the database
      );
    } catch (e) {
      print('Error saving bill: $e');
    }
  }

  /// Delete a bill from database
  static Future<void> deleteBill(int id) async {
    try {
      await DatabaseProvider.db.deleteBill(id);
    } catch (e) {
      print('Error deleting bill: $e');
    }
  }
}
