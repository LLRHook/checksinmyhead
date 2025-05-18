// Checkmate: Privacy-first receipt spliting
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

import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:checks_frontend/screens/settings/services/settings_manager.dart';
import 'package:flutter/material.dart';

/// RecentBillShareUtils
///
/// A utility class that handles the sharing functionality for recent bills.
/// This class provides a bridge between the RecentBillModel and the ShareUtils,
/// preparing all necessary data from a saved bill for sharing.
///
/// The class handles:
/// 1. Retrieving user-defined share options from settings
/// 2. Extracting bill participants and their shares
/// 3. Converting bill data into a shareable text format
/// 4. Initiating the share action with the formatted text
///
/// This utility is specifically designed to work with the RecentBillModel,
/// which represents a bill that has been previously saved by the user.
class RecentBillShareUtils {
  /// Shares a bill with external apps using device's share functionality
  ///
  /// This method performs the following steps:
  /// 1. Retrieves user's share preferences from settings
  /// 2. Extracts participant and item details from the bill model
  /// 3. Generates a formatted text summary based on share options
  /// 4. Triggers the system share sheet with the formatted text
  ///
  /// Parameters:
  /// - context: The BuildContext for potential UI interactions
  /// - bill: The RecentBillModel containing all bill information to be shared
  ///
  /// Note: This method uses a name-based lookup approach for matching
  /// participants with their shares to ensure reliable lookups even if
  /// Person object references have changed.
  static Future<void> shareBill(
    BuildContext context,
    RecentBillModel bill,
  ) async {
    // Retrieve user's share preferences from settings storage
    final shareOptions = await SettingsManager.getShareOptions();

    // Extract participant information from the bill
    final participants = bill.participants;

    // Get the amount each person needs to pay
    final Map<Person, double> personShares = bill.generatePersonShares();

    // Create a name-based map for more reliable lookups
    // This prevents issues if Person objects are recreated between sessions
    final Map<String, double> personSharesByName = {};
    personShares.forEach((person, amount) {
      personSharesByName[person.name] = amount;
    });

    // Reconstruct bill items from the saved bill data
    final List<BillItem> items = bill.getBillItems();

    // Generate the shareable text summary based on user preferences
    // Using name-based lookups for better reliability with saved data
    final String summary = await ShareUtils.generateShareTextWithNameLookup(
      participants: participants,
      personSharesByName: personSharesByName,
      items: items,
      subtotal: bill.subtotal,
      tax: bill.tax,
      tipAmount: bill.tipAmount,
      total: bill.total,
      tipPercentage: bill.tipPercentage,
      isCustomTipAmount:
          bill.tipPercentage ==
          0, // A tip percentage of 0 indicates custom amount
      includeItemsInShare: shareOptions.showAllItems,
      includePersonItemsInShare: shareOptions.showPersonItems,
      hideBreakdownInShare: !shareOptions.showBreakdown,
    );

    // Trigger the device's share functionality with the formatted text
    ShareUtils.shareBillSummary(summary: summary);
  }
}
