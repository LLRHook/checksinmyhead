import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/rendering.dart';
import 'recent_bill_model.dart';

/// RecentBillsManager
///
/// A utility class that provides static methods to manage bill data persistence.
/// This class acts as a facade between the UI and the database layer,
/// providing simplified methods for common operations on bill data.
///
/// The manager handles database interactions for:
/// - Retrieving all saved bills
/// - Saving new bills with complete bill information
/// - Deleting individual bills
/// - Clearing all bill history
///
/// This class catches and handles database errors, providing graceful fallbacks
/// and error logging to simplify error handling in the UI layers.
class RecentBillsManager {
  /// Retrieves all recent bills from the database
  ///
  /// This method fetches all saved bills from the local database and
  /// converts the raw data into usable RecentBillModel objects.
  ///
  /// Returns:
  /// - A list of RecentBillModel objects if successful
  /// - An empty list if the database is empty or an error occurs
  ///
  /// The method handles exceptions internally to prevent crashes
  /// in the UI when database errors occur.
  static Future<List<RecentBillModel>> getRecentBills() async {
    try {
      // Fetch raw bill data from the database
      final recentBillsData = await DatabaseProvider.db.getRecentBills();

      // Convert each raw data entry to a RecentBillModel object
      return recentBillsData.map(RecentBillModel.fromData).toList();
    } catch (e) {
      // Return an empty list if any error occurs to prevent UI crashes
      return [];
    }
  }

  /// Saves a new bill to the database
  ///
  /// This method persists all bill information to the local database,
  /// including participant data, items, financial information, and settings.
  ///
  /// Parameters:
  /// - participants: List of people involved in the bill
  /// - personShares: Map associating each person with their share amount
  /// - items: List of individual bill items with prices and assignments
  /// - subtotal: Sum of all item prices before tax and tip
  /// - tax: Tax amount
  /// - tipAmount: Tip amount
  /// - total: Total bill amount (subtotal + tax + tip)
  /// - birthdayPerson: Optional person celebrating their birthday (for special splitting)
  /// - tipPercentage: Percentage of the bill added as tip (default: 0)
  /// - isCustomTipAmount: Whether the tip was entered as a custom amount (default: false)
  ///
  /// Errors during saving are caught and logged but not propagated to prevent UI crashes.
  static Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    Person? birthdayPerson,
    double tipPercentage = 0, // Tip percentage with default value of 0
    bool isCustomTipAmount =
        false, // Flag for custom tip amount with default value
  }) async {
    try {
      // Forward all data to the database provider
      await DatabaseProvider.db.saveBill(
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tipAmount: tipAmount,
        total: total,
        tipPercentage: tipPercentage, // Pass tip percentage to database
      );
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error saving bill: $e');
    }
  }

  /// Deletes a specific bill from the database
  ///
  /// This method removes a single bill from the database based on its ID.
  ///
  /// Parameters:
  /// - id: The unique identifier of the bill to delete
  ///
  /// Errors during deletion are caught and logged but not propagated
  /// to prevent UI crashes.
  static Future<void> deleteBill(int id) async {
    try {
      // Request deletion from the database provider
      await DatabaseProvider.db.deleteBill(id);
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error deleting bill: $e');
    }
  }

  /// Clears all bills from the database
  ///
  /// This method removes all saved bills from the database,
  /// effectively resetting the bill history.
  ///
  /// This operation cannot be undone and should be used with caution,
  /// typically with user confirmation before calling.
  ///
  /// Errors during clearing are caught and logged but not propagated
  /// to prevent UI crashes.
  static Future<void> clearAllBills() async {
    try {
      // Request complete clearing from the database provider
      await DatabaseProvider.db.clearAllBills();
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error deleting all bills: $e');
    }
  }
}
