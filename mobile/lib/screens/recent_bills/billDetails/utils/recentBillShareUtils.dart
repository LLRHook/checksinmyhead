import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:checks_frontend/utils/settings_manager.dart';
import 'package:flutter/material.dart';

class RecentBillShareUtils {
  static Future<void> shareBill(
    BuildContext context,
    RecentBillModel bill,
  ) async {
    // Get share options
    final shareOptions = await SettingsManager.getShareOptions();

    // Get participants as Person objects
    final participants = bill.participants;

    // Generate person shares from bill data
    final Map<Person, double> personShares = bill.generatePersonShares();

    // Create a name-based map for reliable lookups
    final Map<String, double> personSharesByName = {};
    personShares.forEach((person, amount) {
      personSharesByName[person.name] = amount;
    });

    // Generate bill items from saved data
    final List<BillItem> items = bill.getBillItems();

    // Use the new method with name-based lookups
    final String summary = await ShareUtils.generateShareTextWithNameLookup(
      participants: participants,
      personSharesByName: personSharesByName,
      items: items,
      subtotal: bill.subtotal,
      tax: bill.tax,
      tipAmount: bill.tipAmount,
      total: bill.total,
      tipPercentage: bill.tipPercentage,
      isCustomTipAmount: bill.tipPercentage == 0,
      includeItemsInShare: shareOptions.includeItemsInShare,
      includePersonItemsInShare: shareOptions.includePersonItemsInShare,
      hideBreakdownInShare: shareOptions.hideBreakdownInShare,
    );

    // Share the summary
    ShareUtils.shareBillSummary(context: context, summary: summary);
  }
}
