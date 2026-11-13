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
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

class RecentBillShareUtils {
  static Future<void> shareBill(RecentBillModel bill) async {
    if (bill.identityNeedsReview) {
      final text = StringBuffer(
        '${bill.billName}\nRecorded receipt; ownership needs review.\nTotal: ${CurrencyFormatter.formatCurrency(bill.displayTotal, currencyCode: bill.currencyCode)}\n',
      );
      for (var i = 0; i < bill.recordedShares.length; i++) {
        final row = bill.recordedShares[i];
        final amount = row['total'];
        text.writeln(
          'Recorded row ${row['id'] ?? row['recorded_share_id'] ?? i + 1} · ${row['person_name'] ?? row['name'] ?? 'Unnamed'}: ${amount is num && amount.isFinite ? CurrencyFormatter.formatCurrency(amount.toDouble(), currencyCode: bill.currencyCode) : 'amount unavailable'}',
        );
      }
      if (bill.recordedShares.isEmpty) {
        text.writeln(
          'Per-person amounts unavailable; recorded item assignments need review.',
        );
      }
      if (bill.shareUrl?.startsWith('https://') == true) {
        text.writeln(bill.shareUrl);
      }
      ShareUtils.shareBillSummary(summary: text.toString());
      return;
    }
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
      birthdayPerson:
          bill.birthdayRef == null && bill.birthdayName == null
              ? null
              : participants
                  .where(
                    (p) =>
                        bill.birthdayRef != null
                            ? p.clientRef == bill.birthdayRef
                            : p.name == bill.birthdayName,
                  )
                  .firstOrNull,
      tipPercentage: bill.tipPercentage,
      isCustomTipAmount: bill.isCustomTipAmount,
      showAllItems: shareOptions.showAllItems,
      showPersonItems: shareOptions.showPersonItems,
      showBreakdown: !shareOptions.showBreakdown,
      currencyCode: bill.currencyCode,
    );

    ShareUtils.shareBillSummary(summary: summary);
  }
}
