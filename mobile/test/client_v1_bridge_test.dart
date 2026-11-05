import 'dart:convert';
import 'save_receipt_test.dart' show creationResponse;
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bottom_bar.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/providers/assignment_provider.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/item_card.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/widgets/add_person_field.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/components/recent_bill_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

final _syntheticKey = base64Url.encode(List.filled(32, 1)).replaceAll('=', '');

final alex = Person(name: 'Alex', color: Colors.blue);
final sam = Person(name: 'Sam', color: Colors.green);

Future<BillUploadResponse> upload(
  List<BillItem> items, {
  List<Person>? participants,
  Map<Person, double>? shares,
  bool lazy = false,
  double subtotal = 10,
}) async {
  final api = ApiService();
  final body = api.buildBillRequest(
    billName: 'Snack',
    participants: participants ?? [alex, sam],
    personShares: shares ?? {alex: 10, sam: 0},
    items: items,
    subtotal: subtotal,
    tax: 0,
    tipAmount: 0,
    tipPercentage: 0,
    total: subtotal,
    paymentMethods: const [],
    currencyCode: 'USD',
    lazyMode: lazy,
  );
  return api.publishSnapshot(jsonEncode(body), _syntheticKey);
}

void main() {
  testWidgets(
    'ItemCard through provider uploads positive assignments and keeps zero shares',
    (tester) async {
      final item = BillItem(name: 'Snack', price: 10, assignments: {});
      final provider = AssignmentProvider(
        participants: [alex, sam],
        items: [item],
        subtotal: 10,
        tax: 0,
        tipAmount: 0,
        total: 10,
        tipPercentage: 0,
        isCustomTipAmount: false,
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: provider,
              builder:
                  (context, _) => ItemCard(
                    item: item,
                    participants: provider.participants,
                    assignedPercentage: item.assignments.values.fold(
                      0,
                      (a, b) => a + b,
                    ),
                    assignedPeople:
                        item.assignments.entries
                            .where((e) => e.value > 0)
                            .map((e) => e.key)
                            .toList(),
                    universalItemIcon: Icons.restaurant,
                    onAssign: provider.assignItem,
                    onSplitEvenly: provider.splitItemEvenly,
                    onShowCustomSplit: (_, _) {},
                    birthdayPerson: provider.birthdayPerson,
                    onBirthdayToggle: provider.toggleBirthdayPerson,
                    getPersonBillPercentage: provider.getPersonBillPercentage,
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Snack'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex').first);
      await tester.pump();
      expect(item.assignments, {alex: 100, sam: 0});
      expect(provider.personFinalShares, {alex: 10, sam: 0});
      Map<String, dynamic>? sent;
      var requests = 0;
      await http.runWithClient(
        () => upload(provider.items, shares: provider.personFinalShares),
        () => MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.headers['Idempotency-Key'], _syntheticKey);
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(creationResponse(sent!, id: 1)), 201);
        }),
      );
      expect(requests, 1);
      expect((sent!['items'] as List).single['assignments'], [
        {'person_name': 'Alex', 'percentage': 100},
      ]);
      expect(sent!['participants'], [
        {'name': 'Alex'},
        {'name': 'Sam'},
      ]);
      final shares = sent!['person_shares'] as List;
      expect(shares.last, {
        'person_name': 'Sam',
        'items': [],
        'subtotal': 0,
        'tax_share': 0,
        'tip_share': 0,
        'total': 0,
      });
      expect(item.assignments, {alex: 100, sam: 0});
      await tester.pumpAndSettle();
    },
  );

  for (final bad in [
    double.nan,
    double.infinity,
    double.negativeInfinity,
    -1.0,
    100.01,
  ]) {
    test('upload rejects percentage $bad before HTTP', () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            upload([
              BillItem(
                name: 'Snack',
                price: 10,
                assignments: {alex: 100, sam: bad},
              ),
            ]),
            throwsA(
              isA<ApiException>().having(
                (e) => e.message,
                'message',
                contains('percentage'),
              ),
            ),
          );
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 201);
        }),
      );
      expect(requests, 0);
    });
  }

  for (final name in [
    'A' * 30,
    'é' * 30,
    '界' * 30,
    '😀' * 30,
    'e\u0301' * 15,
  ]) {
    test('upload accepts 30-rune label ${name.runes.first}', () async {
      final person = Person(name: name, color: Colors.blue);
      Map<String, dynamic>? sent;
      var requests = 0;
      await http.runWithClient(
        () => upload(
          [
            BillItem(name: 'Snack', price: 10, assignments: {person: 100}),
          ],
          participants: [person],
          shares: {person: 10},
        ),
        () => MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.headers['Idempotency-Key'], _syntheticKey);
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(creationResponse(sent!, id: 1)), 201);
        }),
      );
      expect(requests, 1);
      expect(sent!['participants'], [
        {'name': name},
      ]);
    });
  }

  for (final location in ['participant', 'share', 'assignment']) {
    test('upload rejects 31-rune $location without changing labels', () async {
      final name = '😀' * 31;
      final person = Person(name: name, color: Colors.blue);
      final participants = location == 'participant' ? [person] : [alex];
      final shares = location == 'share' ? {person: 10.0} : {alex: 10.0};
      final item = BillItem(
        name: 'Snack',
        price: 10,
        assignments: {location == 'assignment' ? person : alex: 100},
      );
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            upload([item], participants: participants, shares: shares),
            throwsA(
              isA<ApiException>().having(
                (e) => e.message,
                'message',
                contains('30'),
              ),
            ),
          );
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 201);
        }),
      );
      expect(requests, 0);
      expect(person.name, name);
      expect(item.assignments.length, 1);
      expect(participants.length, 1);
      expect(shares.length, 1);
    });
  }

  testWidgets(
    'typed participant entry reports 31 runes and accepts supported Unicode',
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
      await tester.enterText(find.byType(TextFormField), 'A' * 31);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.textContaining('30'), findsOneWidget);
      expect(provider.participants, isEmpty);
      await tester.enterText(find.byType(TextFormField), '😀' * 30);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(provider.participants.single.name, '😀' * 30);
    },
  );

  test(
    'recent entry rejects long label without rewriting the original person',
    () {
      final provider = ParticipantsProvider();
      addTearDown(provider.dispose);
      final person = Person(name: 'A' * 31, color: Colors.blue);
      expect(provider.addRecentPerson(person), isFalse);
      expect(provider.participants, isEmpty);
      expect(person.name, 'A' * 31);
    },
  );

  for (final invalidName in [false, true]) {
    testWidgets(
      'Done visibly rejects invalid ${invalidName ? 'name' : 'percentage'} before saving',
      (tester) async {
        final person =
            invalidName ? Person(name: 'A' * 31, color: Colors.blue) : alex;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      onPressed:
                          () => DoneButtonHandler.handleDone(
                            context,
                            data: BillSummaryData(
                              participants: [person],
                              personShares: {person: 10},
                              items: [
                                BillItem(
                                  name: 'Snack',
                                  price: 10,
                                  assignments: {
                                    person: invalidName ? 100 : double.nan,
                                  },
                                ),
                              ],
                              subtotal: 10,
                              tax: 0,
                              tipAmount: 0,
                              total: 10,
                            ),
                          ),
                      child: const Text('Save receipt'),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Save receipt'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(invalidName ? '30' : 'percentage'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'group entry rejects the whole group without silently dropping its long name',
    () {
      final provider = ParticipantsProvider();
      addTearDown(provider.dispose);
      provider.addRecentPerson(sam);
      final longName = Person(name: '界' * 31, color: Colors.red);
      final group = [alex, longName];
      expect(provider.addGroup(group), isFalse);
      expect(provider.participants.map((p) => p.name), [sam.name]);
      expect(provider.participants.single.clientRef, isNot(sam.clientRef));
      expect(provider.validationError, contains('30'));
      expect(group.map((p) => p.name), ['Alex', '界' * 31]);
      expect(provider.addGroup([alex]), isTrue);
      expect(provider.participants.map((p) => p.name), [sam.name, alex.name]);
    },
  );

  for (final assignments in <Map<Person, double>>[
    {},
    {alex: 0, sam: -0.0},
    {alex: 25, sam: 0},
  ]) {
    test(
      'lazy upload preserves empty and partial claims ${assignments.length}/${assignments[alex]}',
      () async {
        Map<String, dynamic>? sent;
        var requests = 0;
        await http.runWithClient(
          () => upload(
            [
              BillItem(name: 'Repeated', price: 10, assignments: assignments),
              BillItem(
                name: 'Repeated',
                price: -1,
                assignments: {alex: 100 / 3, sam: 200 / 3},
              ),
            ],
            participants: [],
            shares: {},
            lazy: true,
            subtotal: 9,
          ),
          () => MockClient((request) async {
            requests++;
            expect(request.method, 'POST');
            expect(request.headers['Idempotency-Key'], _syntheticKey);
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(creationResponse(sent!, id: 1)),
              201,
            );
          }),
        );
        expect(requests, 1);
        final items = sent!['items'] as List;
        expect(items.map((i) => i['name']), ['Repeated', 'Repeated']);
        expect(items.map((i) => i['price']), [10, -1]);
        expect(
          items.first['assignments'],
          assignments[alex] == 25
              ? [
                {'person_name': 'Alex', 'percentage': 25},
              ]
              : isEmpty,
        );
        expect(items.last['assignments'], [
          {'person_name': 'Alex', 'percentage': 100 / 3},
          {'person_name': 'Sam', 'percentage': 200 / 3},
        ]);
        expect(sent!['lazy_mode'], isTrue);
      },
    );
  }

  test(
    'upload rejects an overallocated item without changing partial-claim policy',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            upload([
              BillItem(
                name: 'Snack',
                price: 10,
                assignments: {alex: 60, sam: 50},
              ),
            ]),
            throwsA(
              isA<ApiException>().having(
                (e) => e.message,
                'message',
                contains('percentages'),
              ),
            ),
          );
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 201);
        }),
      );
      expect(requests, 0);
    },
  );

  testWidgets(
    'saved receipt Get Link shows validation and leaves the old label readable',
    (tester) async {
      final name = 'A' * 31;
      final model = RecentBillModel(
        id: 1,
        billName: 'Old receipt',
        participantNames: [name],
        participantCount: 1,
        total: 10,
        date: DateTime(2026),
        subtotal: 10,
        tax: 0,
        tipAmount: 0,
        color: Colors.blue,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentBillCard(
              bill: model,
              onDeleted: () {},
              onRefreshNeeded: () {},
              onRetryUpload: () async {
                await upload(
                  model.getBillItems(),
                  participants: model.participants,
                  shares: model.generatePersonShares(),
                );
                return null;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Get Link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('30 Unicode'), findsOneWidget);
      expect(model.participantNames, [name]);
      expect(model.participants.single.name, name);
      expect(model.shareUrl, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'maintained attachment, settlement and settings keep distinct capabilities',
    () async {
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          final api = ApiService();
          await api.addBillToTab(
            9,
            1,
            'tab-proof',
            billToken: 'source-proof',
            memberToken: 'member-proof',
          );
          await api.updateSettlement(
            9,
            2,
            'tab-proof',
            true,
            memberToken: 'member-proof',
          );
          await api.updateTabDisplayCurrency(
            9,
            'tab-proof',
            'USD',
            memberToken: 'member-proof',
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );
      expect(requests.length, 3);
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer tab-proof');
        expect(request.headers['X-Member-Token'], 'member-proof');
      }
      expect(jsonDecode(requests.first.body), {
        'bill_id': 1,
        'bill_token': 'source-proof',
      });
      expect(requests[1].url.path, '/api/tabs/9/settlements/2');
      expect(jsonDecode(requests[1].body), {'paid': true});
    },
  );
}
