import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/screens/lazy_bill_claim_screen.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> graph({
  bool claimed = false,
  bool attached = true,
  bool empty = false,
}) => {
  'id': 7,
  'name': 'Current receipt',
  'identity_version': 2,
  'identity_state': 'ready',
  'identity_review_status': 'ready',
  'identity_revision':
      empty
          ? 0
          : claimed
          ? 4
          : 3,
  'lazy_mode': true,
  'currency_code': 'USD',
  if (attached) 'tab_id': 9,
  'viewer_member_id': attached ? 22 : null,
  'participants': empty ? [] : [occurrence()],
  'items':
      empty
          ? []
          : [
            {
              'id': 31,
              'name': 'Meal',
              'price': 10,
              'updated_at': '2001-01-01T00:00:00Z',
              'assignments':
                  claimed
                      ? [
                        {
                          'participant_id': 11,
                          'person_name': 'Alex',
                          'percentage': 100,
                        },
                      ]
                      : [],
            },
          ],
  'person_shares':
      claimed
          ? [
            {
              'id': 91,
              'participant_id': 11,
              'person_name': 'Alex',
              'subtotal': 10,
              'tax_share': 1,
              'tip_share': 1,
              'total': 12,
              'paid': false,
            },
          ]
          : [],
  'payment_methods': [],
};
Map<String, dynamic> occurrence({
  String label = 'Alex',
  String ref = 'original',
}) => {
  'participant_id': 11,
  'bill_id': 7,
  'client_ref': ref,
  'label': label,
  'binding_state': 'confirmed',
  'member_id': 22,
  'pending_member_id': null,
  'pending_request_revision': null,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final loseRead in [false, true]) {
    testWidgets(
      'attached claim ACK ${loseRead ? 'read failure retries only GET' : 'reads scoped nonzero graph before payment'}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var claimed = false;
        var tabReads = 0;
        final sent = <http.Request>[];
        final api = ApiService(
          baseUrl: 'https://synthetic.invalid',
          client: MockClient((request) async {
            sent.add(request);
            if (request.url.path.endsWith('/members/me')) {
              return http.Response(
                '{"member_id":22,"tab_id":9,"display_name":"Alex","role":"member"}',
                200,
              );
            }
            expect(request.headers['Authorization'], 'Bearer destination');
            expect(request.headers['X-Member-Token'], 'member-proof');
            if (request.method == 'PATCH') {
              expect(request.url.path, '/api/tabs/9/bills/7/assignments');
              expect(jsonDecode(request.body), {
                'expected_revision': 3,
                'updates': [
                  {
                    'item_id': 31,
                    'expected_updated_at': '2001-01-01T00:00:00Z',
                    'assignments': [
                      {'participant_id': 11, 'percentage': 100.0},
                    ],
                  },
                ],
              });
              claimed = true;
              return http.Response('{"status":"ok"}', 200);
            }
            expect(request.method, 'GET');
            expect(request.url.path, '/api/tabs/9');
            tabReads++;
            if (loseRead && tabReads == 2) return http.Response('{}', 503);
            return http.Response(
              jsonEncode({
                'id': 9,
                'bills': [graph(claimed: claimed)],
              }),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: LazyBillClaimScreen(
              billId: '7',
              token: 'destination',
              tabId: '9',
              memberToken: 'member-proof',
              api: api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alex · #11'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Meal'));
        await tester.tap(find.text('Meal'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review total'));
        await tester.tap(find.text('Review total'));
        await tester.pumpAndSettle();
        if (loseRead) {
          expect(
            find.textContaining(
              'Selection saved. Current total is unavailable',
            ),
            findsOneWidget,
          );
          expect(find.text('Your total'), findsNothing);
          expect(find.text(r'$0.00'), findsNothing);
          await tester.ensureVisible(find.text('Retry current total'));
          await tester.tap(find.text('Retry current total'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Your total'), findsOneWidget);
        expect(find.text(r'$12.00'), findsOneWidget);
        expect(sent.where((r) => r.method == 'PATCH'), hasLength(1));
        expect(tabReads, loseRead ? 3 : 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final loseResponse in [false, true]) {
    testWidgets(
      'actual claim parent creates first occurrence ${loseResponse ? 'with same ref explicit recovery' : 'before selecting returned row'}',
      (tester) async {
        var bill = graph(empty: true, attached: false);
        final bodies = <String>[];
        final api = ApiService(
          baseUrl: 'https://synthetic.invalid',
          client: MockClient((request) async {
            if (request.method == 'POST') {
              bodies.add(request.body);
              final body = jsonDecode(request.body);
              bill = {
                ...bill,
                'identity_revision': 1,
                'participants': [
                  {
                    ...occurrence(label: 'New', ref: body['client_ref']),
                    'binding_state': 'unbound',
                    'member_id': null,
                  },
                ],
              };
              if (loseResponse && bodies.length == 1) {
                throw const SocketException('synthetic lost create response');
              }
              return http.Response(
                jsonEncode({
                  'participant': (bill['participants'] as List).single,
                  'identity_revision': 1,
                }),
                200,
              );
            }
            expect(request.url.path, '/api/bills/7');
            return http.Response(jsonEncode(bill), 200);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: LazyBillClaimScreen(billId: '7', token: 'source', api: api),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'New');
        await tester.tap(find.text('Add occurrence'));
        await tester.pumpAndSettle();
        if (loseResponse) {
          await tester.ensureVisible(
            find.text('Retry original action after review'),
          );
          await tester.tap(find.text('Retry original action after review'));
          await tester.pumpAndSettle();
          expect(bodies, hasLength(2));
          expect(bodies.first, bodies.last);
        } else {
          expect(bodies, hasLength(1));
        }
        expect(find.text('Picking as New'), findsOneWidget);
        expect(find.text('New · #11'), findsOneWidget);
        expect(find.text('Retry original action after review'), findsNothing);
        expect(tester.takeException(), isNull);
        final stored = jsonDecode(
          (await SharedPreferences.getInstance()).getString(
            'participant_v2_7',
          )!,
        );
        expect(stored['participant_id'], 11);
      },
    );
  }
}
