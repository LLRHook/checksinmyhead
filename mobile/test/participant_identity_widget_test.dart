import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/screens/participant_identity_panel.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> participant(
  int id, {
  String label = 'Alex',
  bool pending = false,
}) => {
  'participant_id': id,
  'bill_id': 7,
  'client_ref': 'r$id',
  'label': label,
  'binding_state': pending ? 'pending' : 'unbound',
  'member_id': null,
  'pending_member_id': pending ? 22 : null,
  'pending_request_revision': pending ? 3 : null,
};
Map<String, dynamic> bill(
  List<Map<String, dynamic>> people, {
  int revision = 3,
}) => {
  'id': 7,
  'identity_version': 2,
  'identity_state': 'ready',
  'identity_revision': revision,
  'identity_review_status': 'ready',
  'participants': people,
};
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'paid participant addition shows the server reason without a retry action',
    (tester) async {
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'code': 'participants_locked_paid',
              'error': 'participants cannot be added after a share is paid',
            }),
            409,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ParticipantIdentityPanel(
                bill: bill([participant(11)]),
                token: 'source',
                api: api,
                onChanged: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add occurrence'));
      await tester.pumpAndSettle();
      expect(
        find.text('participants cannot be added after a share is paid'),
        findsOneWidget,
      );
      expect(find.text('Retry original action after review'), findsNothing);
    },
  );
  testWidgets(
    'duplicate occurrence selection survives label rename with exact source participant revision',
    (tester) async {
      var current = bill([participant(11), participant(12)]);
      int? selected;
      late StateSetter update;
      final sent = <http.Request>[];
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((request) async {
          sent.add(request);
          expect(request.url.path, '/api/bills/7/participants/12');
          expect(jsonDecode(request.body), {
            'name': 'Renamed',
            'expected_revision': 3,
          });
          expect(request.headers['Authorization'], 'Bearer source');
          current = bill([
            participant(11),
            participant(12, label: 'Renamed'),
          ], revision: 4);
          return http.Response(
            jsonEncode({
              'participant': participant(12, label: 'Renamed'),
              'identity_revision': 4,
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ParticipantIdentityPanel(
                  bill: current,
                  token: 'source',
                  api: api,
                  selectedId: selected,
                  onSelected: (id) => update(() => selected = id),
                  onChanged: () async => update(() {}),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alex · #11'), findsOneWidget);
      expect(find.text('Alex · #12'), findsOneWidget);
      await tester.tap(find.text('Alex · #12'));
      await tester.pumpAndSettle();
      expect(selected, 12);
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Renamed');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(selected, 12);
      expect(find.text('Renamed · #12'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.text('Renamed · #12'),
                matching: find.byType(ListTile),
              ),
            )
            .selected,
        true,
      );
      final stored = jsonDecode(
        (await SharedPreferences.getInstance()).getString('participant_v2_7')!,
      );
      expect(stored, {'version': 2, 'bill_id': 7, 'participant_id': 12});
    },
  );
  testWidgets(
    'pending request shows generation and deliberate uncertain decision retry keeps original body',
    (tester) async {
      var current = bill([participant(11, pending: true)]);
      late StateSetter update;
      final sent = <String>[];
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '{"member_id":1,"tab_id":9,"display_name":"Alex","role":"creator"}',
              200,
            );
          }
          expect(
            request.url.path,
            '/api/tabs/9/bills/7/participants/11/binding',
          );
          expect(request.headers['X-Member-Token'], 'creator-proof');
          sent.add(request.body);
          current = bill([participant(11)], revision: 4);
          if (sent.length == 1) {
            throw const SocketException('synthetic lost decision response');
          }
          return http.Response(
            jsonEncode({
              'participant': participant(11),
              'identity_revision': 4,
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return ParticipantIdentityPanel(
                    bill: current,
                    token: 'destination',
                    tabId: '9',
                    memberToken: 'creator-proof',
                    api: api,
                    onChanged: () async => update(() {}),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('member #22 requested'), findsOneWidget);
      await tester.tap(find.text('reject request #3'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(find.text('Retry original action after review'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Retry original action after review'),
      );
      await tester.tap(find.text('Retry original action after review'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(2));
      expect(sent[0], sent[1]);
      expect(jsonDecode(sent[1]), {
        'expected_revision': 3,
        'request_revision': 3,
        'member_id': 22,
        'decision': 'reject',
      });
      expect(
        find.textContaining('Pending requests cannot mark a share paid'),
        findsOneWidget,
      );
    },
  );
}
