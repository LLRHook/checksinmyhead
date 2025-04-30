// lib/screens/recent_bills/components/bills_list.dart
import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/recent_bill_model.dart';
import 'recent_bill_card.dart';

class BillsList extends StatelessWidget {
  final List<RecentBillModel> bills;
  final VoidCallback onBillDeleted;

  const BillsList({Key? key, required this.bills, required this.onBillDeleted})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        return RecentBillCard(bill: bills[index], onDeleted: onBillDeleted);
      },
    );
  }
}
