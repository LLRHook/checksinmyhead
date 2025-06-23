// Spliq: Privacy-first receipt spliting
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

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';
import 'recent_bill_model.dart';

/// RecentBillsManager
///
/// A class that manages bill data persistence and provides a clean interface to the database.
/// Acts as a facade between the UI and the database layer, simplifying common operations.
///
/// The manager handles database interactions for:
/// - Retrieving all saved bills
/// - Saving new bills with complete bill information
/// - Deleting individual bills
/// - Clearing all bill history
/// - Updating bill names
///
/// This class catches and handles database errors, providing graceful fallbacks
/// and error logging to simplify error handling in the UI layers.
///
/// Uses a stream to notify listeners when bill data changes, making it easy
/// for UI components to stay updated with the latest data.
class RecentBillsManager extends ChangeNotifier {
  // Singleton instance
  static final RecentBillsManager _instance = RecentBillsManager._internal();

  // Factory constructor to access the singleton instance
  factory RecentBillsManager() => _instance;

  // StreamController for emitting bill data changes
  final _billsStreamController =
      StreamController<List<RecentBillModel>>.broadcast();

  // Stream getter to allow UI components to listen for changes
  Stream<List<RecentBillModel>> get billsStream =>
      _billsStreamController.stream;

  // Private constructor for singleton pattern
  RecentBillsManager._internal();

  // Dispose method to clean up resources
  @override
  void dispose() {
    _billsStreamController.close();
    super.dispose();
  }

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
  ///
  /// Emits the bill data to the stream so listeners are notified of changes.
  Future<List<RecentBillModel>> getRecentBills() async {
    try {
      // Fetch raw bill data from the database
      final recentBillsData = await DatabaseProvider.db.getRecentBills();

      // Convert each raw data entry to a RecentBillModel object
      final bills = recentBillsData.map(RecentBillModel.fromData).toList();

      // Emit the bills to the stream to notify listeners
      _billsStreamController.add(bills);

      return bills;
    } catch (e) {
      debugPrint('Error fetching bills: $e');
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
  ///
  /// Refreshes the bills list after saving to update listeners.
  Future<void> saveBill({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    Person? birthdayPerson,
    double tipPercentage = 0, // Tip percentage with default value of 0
    bool isCustomTipAmount = false,
    required String billName, // Flag for custom tip amount with default value
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
        billName: billName, // Pass bill name to database
      );

      // Refresh the bills list to update listeners
      await getRecentBills();
      notifyListeners();
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
  ///
  /// Refreshes the bills list after deletion to update listeners.
  Future<void> deleteBill(int id) async {
    try {
      // Request deletion from the database provider
      await DatabaseProvider.db.deleteBill(id);

      // Refresh the bills list to update listeners
      await getRecentBills();
      notifyListeners();
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
  ///
  /// Refreshes the bills list after clearing to update listeners.
  Future<void> clearAllBills() async {
    try {
      // Request complete clearing from the database provider
      await DatabaseProvider.db.clearAllBills();

      // Refresh the bills list to update listeners (will be empty)
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error deleting all bills: $e');
    }
  }

  /// Updates the name of a specific bill
  ///
  /// This method renames a single bill based on its ID.
  ///
  /// Parameters:
  /// - id: The unique identifier of the bill to update
  /// - newName: The new name to assign to the bill
  ///
  /// Errors during updating are caught and logged but not propagated
  /// to prevent UI crashes.
  ///
  /// Refreshes the bills list after updating to notify listeners.
  Future<void> updateBillName(int id, String newName) async {
    try {
      // Request update from the database provider
      await DatabaseProvider.db.updateBillName(id, newName);

      // Refresh the bills list to update listeners
      await getRecentBills();
      notifyListeners();
    } catch (e) {
      // Log any errors but don't propagate them to the UI
      debugPrint('Error updating bill name: $e');
    }
  }
}
