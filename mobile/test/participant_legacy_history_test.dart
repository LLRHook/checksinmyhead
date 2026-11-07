import 'dart:convert';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/utils/bill_calculations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'save_receipt_test.dart' show Harness;

void main() {
  testWidgets(
    'legacy duplicate blank raw share rows retain exact amounts flags and IDs after import without guessed zeros',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      final ids = await h.owner.importRemoteTabBills(9, [
        {
          'id': 71,
          'identity_version': 1,
          'identity_state': 'legacy_review',
          'identity_revision': 0,
          'identity_review_status': 'identity_review_required',
          'name': 'Recorded history',
          'currency_code': 'USD',
          'subtotal': 5,
          'total': 5,
          'usd_exchange_rate': 1,
          'usd_total': 5,
          'participants': [],
          'items': [],
          'person_shares': [
            {'id': 811, 'person_name': '', 'total': 2, 'paid': true},
            {'id': 812, 'person_name': '', 'total': 3, 'paid': false},
          ],
        },
      ]);
      final row = (await h.db.getBillById(ids.single))!;
      final model = RecentBillModel.fromData(row);
      expect(model.identityNeedsReview, true);
      expect(model.recordedShares, hasLength(2));
      expect(jsonDecode(row.savedShares!).map((s) => s['recorded_share_id']), [
        811,
        812,
      ]);
      expect(model.generatePersonShares().values, [2, 3]);
      expect(model.generatePersonShares().keys.toSet(), hasLength(2));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SortedParticipantsCard(
              bill: model,
              calculations: BillCalculations(model),
            ),
          ),
        ),
      );
      expect(find.text('Unnamed · recorded row 811'), findsOneWidget);
      expect(find.text('Unnamed · recorded row 812'), findsOneWidget);
      expect(find.text('Marked paid (manual)'), findsOneWidget);
      expect(find.text('Not marked paid'), findsOneWidget);
      expect(find.textContaining('2.00'), findsOneWidget);
      expect(find.textContaining('3.00'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    },
  );
  testWidgets(
    'legacy local assignments without recorded shares display review and raw percentages rather than a computed zero debt',
    (tester) async {
      final model = RecentBillModel(
        id: 8,
        participantNames: ['Alex', 'Alex'],
        participantCount: 2,
        total: 5,
        date: DateTime(2001),
        subtotal: 5,
        tax: 0,
        tipAmount: 0,
        color: Colors.blue,
        items: [
          {
            'name': 'Meal',
            'price': 5,
            'assignments': {'Alex': 100},
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SortedParticipantsCard(
              bill: model,
              calculations: BillCalculations(model),
            ),
          ),
        ),
      );
      expect(find.textContaining('ownership needs review'), findsOneWidget);
      expect(
        find.textContaining('Per-person amounts are unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('Alex: 100'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    },
  );
}
