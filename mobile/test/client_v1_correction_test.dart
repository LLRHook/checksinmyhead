import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/widgets/add_person_field.dart';
import 'package:checks_frontend/screens/recent_bills/components/recent_bill_card.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixture;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final alex = Person(name: 'Alex', color: Colors.blue);
  final sam = Person(name: 'Sam', color: Colors.green);

  setUpAll(() async {
    fixture = await Directory.systemTemp.createTemp('billington-client-v1-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => fixture.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDownAll(() async {
    await DatabaseProvider.db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await fixture.delete(recursive: true);
  });

  Future<RecentBillModel> saveHistory(int id, double percentage) async {
    await DatabaseProvider.db.saveBill(
      billId: id,
      participants: [alex, sam],
      personShares: {alex: 10, sam: 0},
      items: [
        BillItem(
          name: 'Snack',
          price: 10,
          assignments: {alex: 100, sam: percentage},
        ),
      ],
      subtotal: 10,
      tax: 0,
      tipAmount: 0,
      total: 10,
      billName: 'Saved receipt $id',
      skipDuplicateCheck: true,
    );
    return RecentBillModel.fromData(
      (await DatabaseProvider.db.getBillById(id))!,
    );
  }

  for (final percentage in [-1.0, 101.0]) {
    test(
      'saved assignment $percentage cannot publish or change history',
      () async {
        final id = percentage < 0 ? 101 : 102;
        await saveHistory(id, percentage);
        final original = (await DatabaseProvider.db.getBillById(id))!;
        var requests = 0;
        await http.runWithClient(
          () => expectLater(
            RecentBillsManager().retrySingleBillUpload(id),
            throwsA(
              isA<BillValidationException>().having(
                (e) => e.message,
                'message',
                contains('percentage'),
              ),
            ),
          ),
          () => MockClient((_) async {
            requests++;
            return http.Response(
              '{"bill_id":1,"share_url":"https://example.test/b/1"}',
              201,
            );
          }),
        );
        final retained = (await DatabaseProvider.db.getBillById(id))!;
        expect(requests, 0);
        expect(retained.shareUrl, isNull);
        expect(retained.items, original.items);
        expect(retained.participants, original.participants);
      },
    );
  }

  test(
    'saved zero assignment publishes with its participant and zero share',
    () async {
      await saveHistory(103, 0);
      final original = (await DatabaseProvider.db.getBillById(103))!;
      Map<String, dynamic>? payload;
      final link = await http.runWithClient(
        () => RecentBillsManager().retrySingleBillUpload(103),
        () => MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"bill_id":1,"share_url":"https://example.test/b/1"}',
            201,
          );
        }),
      );
      expect(link, 'https://example.test/b/1');
      expect(payload!['participants'], [
        {'name': 'Alex'},
        {'name': 'Sam'},
      ]);
      expect((payload!['items'] as List).single['assignments'], [
        {'person_name': 'Alex', 'percentage': 100},
      ]);
      expect(
        (payload!['person_shares'] as List).singleWhere(
          (p) => p['person_name'] == 'Sam',
        )['total'],
        0,
      );
      final retained = (await DatabaseProvider.db.getBillById(103))!;
      expect(retained.shareUrl, link);
      expect(retained.items, original.items);
    },
  );

  testWidgets('saved negative Get Link shows content error and stays pending', (
    tester,
  ) async {
    late RecentBillModel model;
    BillValidationException? validation;
    var requests = 0;
    await tester.runAsync(() async {
      model = await saveHistory(104, -1);
      await http.runWithClient(
        () async {
          try {
            await RecentBillsManager().retrySingleBillUpload(104);
          } on BillValidationException catch (error) {
            validation = error;
          }
        },
        () => MockClient((_) async {
          requests++;
          return http.Response(
            '{"bill_id":1,"share_url":"https://example.test/b/1"}',
            201,
          );
        }),
      );
    });
    expect(validation, isNotNull);
    // Deliver the actual manager error through the card callback. Native SQLite
    // runs above in real async; widget frames use Flutter's controlled clock.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentBillCard(
            bill: model,
            onDeleted: () {},
            onRefreshNeeded: () {},
            onRetryUpload: () async => throw validation!,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Get Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('percentage'), findsOneWidget);
    expect(requests, 0);
    expect(model.shareUrl, isNull);
    final retained = await tester.runAsync(
      () => DatabaseProvider.db.getBillById(104),
    );
    expect(retained!.shareUrl, isNull);
    expect(jsonDecode(retained.items!).single['assignments']['Sam'], -1);
    expect(tester.takeException(), isNull);
  });

  for (final tagged in [false, true]) {
    for (final letters in [29, 30]) {
      test(
        'BOM ${tagged ? 'tagged' : 'raw'} $letters-letter upload matches server rune limit',
        () async {
          final raw = '\uFEFF${'A' * letters}';
          final name = tagged ? '<b>$raw</b>' : raw;
          final person = Person(name: name, color: Colors.blue);
          var requests = 0;
          Map<String, dynamic>? sent;
          await http.runWithClient(
            () async {
              final operation = ApiService().uploadBill(
                billName: 'Snack',
                participants: [person],
                personShares: {person: 10},
                items: [
                  BillItem(
                    name: 'Snack',
                    price: 10,
                    assignments: {person: 100},
                  ),
                ],
                subtotal: 10,
                tax: 0,
                tipAmount: 0,
                tipPercentage: 0,
                total: 10,
                paymentMethods: const [],
              );
              if (letters == 30) {
                await expectLater(
                  operation,
                  throwsA(
                    isA<BillValidationException>().having(
                      (e) => e.message,
                      'message',
                      contains('30 Unicode'),
                    ),
                  ),
                );
              } else {
                await operation;
              }
            },
            () => MockClient((request) async {
              requests++;
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response('{"bill_id":1}', 201);
            }),
          );
          expect(requests, letters == 30 ? 0 : 1);
          if (letters == 29) {
            expect((sent!['participants'] as List).single['name'], name);
          }
          expect(person.name, name);
        },
      );
    }
  }

  testWidgets(
    'tagged BOM entry reports 31 runes and accepts 30 without rewriting',
    (tester) async {
      final provider = ParticipantsProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: AddPersonField())),
        ),
      );
      await tester.tap(find.text('Add Person'));
      await tester.pumpAndSettle();
      final invalid = '<b>\uFEFF${'A' * 30}</b>';
      await tester.enterText(find.byType(TextFormField), invalid);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(provider.participants, isEmpty);
      expect(find.textContaining('30 Unicode'), findsOneWidget);
      final valid = '<b>\uFEFF${'A' * 29}</b>';
      await tester.enterText(find.byType(TextFormField), valid);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(provider.participants.single.name, valid);
    },
  );
}
