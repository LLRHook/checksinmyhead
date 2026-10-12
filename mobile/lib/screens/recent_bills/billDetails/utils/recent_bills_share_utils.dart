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

import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:checks_frontend/screens/settings/services/settings_manager.dart';

class RecentBillShareUtils {
  static Future<void> shareBill(RecentBillModel bill) async {
    final shareOptions = await SettingsManager.getShareOptions();
    final participants = bill.participants;
    final personShares = bill.generatePersonShares();

    final items = bill.getBillItems();

    final summary = await ShareUtils.generateShareText(
      participants: participants,
      personShares: personShares,
      items: items,
      subtotal: bill.subtotal,
      tax: bill.tax,
      tipAmount: bill.tipAmount,
      total: bill.total,
      birthdayPerson: null,
      tipPercentage: bill.tipPercentage,
      isCustomTipAmount: bill.tipPercentage == 0,
      showAllItems: shareOptions.showAllItems,
      showPersonItems: shareOptions.showPersonItems,
      showBreakdown: !shareOptions.showBreakdown,
      currencyCode: bill.currencyCode,
    );

    ShareUtils.shareBillSummary(summary: summary);
  }
}
