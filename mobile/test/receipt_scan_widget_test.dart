import 'dart:async';
import 'dart:convert';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/receipt_review_sheet.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/scan_receipt_button.dart';
import 'package:checks_frontend/services/receipt_api_service.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'receipt_service_test.dart' show ScriptClient, response;

class Harness {
  final BillData bill = BillData();
  final ScriptClient client;
  final Future<ParsedReceipt?> Function(BuildContext, ParsedReceipt)? review;
  late final ReceiptApiService service;
  Harness(this.client, {this.review}) {
    service = ReceiptApiService.forTesting(
      baseUrl: Uri.parse('http://127.0.0.1:1'),
      createClient:
          () => client.sends == 0 ? client : ScriptClient(client.reply),
      prepareImage: (_) async => http.MultipartFile.fromBytes('image', [1]),
    );
  }
  Widget tree({bool show = true}) => ChangeNotifierProvider.value(
    value: bill,
    child: MaterialApp(
      home: Scaffold(
        body:
            show
                ? ScanReceiptButton(
                  createReceiptApi: () => service,
                  pickImage: (_) async => XFile('fixture'),
                  reviewReceipt: review,
                )
                : const Text('Removed'),
      ),
    ),
  );
}

Future<void> startScan(WidgetTester tester) async {
  await tester.tap(find.text('Scan Receipt').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gallery'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  // StreamIterator.cancel() may return the SDK's root-zone completed future;
  // let real microtasks settle while retaining the real production service.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  testWidgets(
    'manual review confirms only after Apply and preserves repeated discounts',
    (tester) async {
      final h = Harness(
        ScriptClient(
          (_) => response(
            '{"vendor":"Test","items":[{"name":"Same","price":10,"quantity":3},{"name":"Same","price":-1}],"subtotal":9}',
          ),
        ),
      );
      addTearDown(h.bill.dispose);
      await tester.pumpWidget(h.tree());
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptReviewSheet), findsOneWidget);
      expect(h.bill.items, isEmpty);
      expect(find.text('-1.00'), findsOneWidget);
      await tester.tap(find.text('Apply to Bill'));
      await tester.pumpAndSettle();
      expect(h.bill.items.map((i) => i.price), [3.33, 3.33, 3.34, -1]);
      expect(h.bill.scannedVendor, 'Test');
      expect(h.client.closes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'disposal during network cancels actual operation and late completion stays silent',
    (tester) async {
      final body = StreamController<List<int>>();
      var cancelled = false;
      body.onCancel = () => cancelled = true;
      final h = Harness(
        ScriptClient((_) => http.StreamedResponse(body.stream, 200)),
      );
      addTearDown(h.bill.dispose);
      await tester.pumpWidget(h.tree());
      await startScan(tester);
      expect(find.text('Scanning Receipt...'), findsOneWidget);
      await tester.pumpWidget(h.tree(show: false));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(h.client.closes, 1);
      expect(cancelled, isTrue);
      body.add(utf8.encode('{"items":[{"name":"Late","price":1}]}'));
      await tester.runAsync(body.close);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(h.bill.items, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
  testWidgets(
    'disposed screen never applies a late review result or touches context',
    (tester) async {
      final review = Completer<ParsedReceipt?>();
      var reviewed = false;
      final h = Harness(
        ScriptClient(
          (_) => response('{"items":[{"name":"Original","price":1}]}'),
        ),
        review: (_, receipt) {
          reviewed = true;
          return review.future;
        },
      );
      addTearDown(h.bill.dispose);
      await tester.pumpWidget(h.tree());
      await startScan(tester);
      expect(reviewed, isTrue);
      await tester.pumpWidget(h.tree(show: false));
      review.complete(
        const ParsedReceipt(items: [ParsedItem(name: 'Late', price: 1)]),
      );
      await tester.pumpAndSettle();
      expect(h.bill.items, isEmpty);
      expect(h.bill.scannedVendor, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'active invalid reviewed candidate gives validation message without mutation and permits retry',
    (tester) async {
      var reviews = 0;
      final h = Harness(
        ScriptClient((_) => response('{"items":[{"name":"Good","price":1}]}')),
        review: (_, receipt) async {
          reviews++;
          return reviews == 1
              ? const ParsedReceipt(
                currencyCode: 'EUR',
                items: [ParsedItem(name: 'Too many', price: 1, quantity: 501)],
              )
              : receipt;
        },
      );
      addTearDown(h.bill.dispose);
      await tester.pumpWidget(h.tree());
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(find.text(ReceiptValidationException.message), findsOneWidget);
      expect(h.bill.currencyCode, 'USD');
      expect(h.bill.items, isEmpty);
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(h.bill.items.single.name, 'Good');
      expect(reviews, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'manual network retry remains available after finite rate-limit error',
    (tester) async {
      var sends = 0;
      final h = Harness(
        ScriptClient(
          (_) =>
              ++sends == 1
                  ? response('{"error":"TAINT"}', status: 429)
                  : response('{"items":[{"name":"Good","price":1}]}'),
        ),
        review: (_, receipt) async => receipt,
      );
      addTearDown(h.bill.dispose);
      await tester.pumpWidget(h.tree());
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Too many scans. Please wait a moment and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('TAINT'), findsNothing);
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(sends, 2);
      expect(h.bill.items.single.name, 'Good');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
