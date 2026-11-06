import 'dart:io';

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_total_card.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/person_card.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/dialogs/custom_split_dialog.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/item_card.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/participant_avatar.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/participant_selector.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/participant_selection_sheet.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/widgets/add_person_field.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/utils/bill_calculations.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color ink, Color surface) {
  final a = Color.alphaBlend(ink, surface).computeLuminance();
  final b = surface.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Widget app(
  Widget body, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme:
      brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
  home: Scaffold(body: SafeArea(child: body)),
);

void useDisplay(
  WidgetTester tester, {
  double width = 466,
  double height = 1000,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = const FakeViewPadding(left: 19, right: 19, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(
    left: 19,
    right: 19,
    bottom: 34,
  );
  addTearDown(tester.view.reset);
}

List<Person> people(int count) => [
  for (var i = 0; i < count; i++)
    Person(
      name: String.fromCharCode(65 + i),
      color: ColorUtils.getParticipantColors()[i],
    ),
];

RecentBillModel savedBill(
  List<Person> roster,
  List<Map<String, dynamic>> items,
) => RecentBillModel(
  id: 1,
  participantNames: [for (final person in roster) person.name],
  participantCount: roster.length,
  total: 122,
  date: DateTime(2026, 10, 30),
  subtotal: 122,
  tax: 0,
  tipAmount: 0,
  color: roster.first.color,
  items: items,
  receiptParticipants: roster,
);

Future<void> pumpParticipants(
  WidgetTester tester,
  RecentBillModel bill, {
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  app(
    SingleChildScrollView(
      child: SortedParticipantsCard(
        bill: bill,
        calculations: BillCalculations(bill),
      ),
    ),
    brightness: brightness,
  ),
);

Widget assignedCard(List<Person> roster) => ItemCard(
  item: BillItem(
    name: 'Truffle fries',
    price: 12,
    assignments: {for (final person in roster) person: 100 / roster.length},
  ),
  participants: roster,
  assignedPercentage: 100,
  assignedPeople: roster,
  universalItemIcon: Icons.restaurant_menu,
  onAssign: (_, _) {},
  onSplitEvenly: (_, _) {},
  onShowCustomSplit: (_, _) {},
  birthdayPerson: null,
  onBirthdayToggle: (_) {},
  getPersonBillPercentage: (_) => 0,
);

BillSummaryData summary(Person person) => BillSummaryData(
  participants: [person],
  personShares: {person: 25},
  items: [
    BillItem(name: 'Synthetic meal', price: 20, assignments: {person: 100}),
  ],
  subtotal: 20,
  tax: 2,
  tipAmount: 3,
  total: 25,
);

Text textWidget(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder);

void expectInside(WidgetTester tester, Finder finder, Rect bounds) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(bounds.left - .5));
  expect(rect.right, lessThanOrEqualTo(bounds.right + .5));
  expect(rect.top, greaterThanOrEqualTo(bounds.top - .5));
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bill Details identity', () {
    final maya = Person(name: 'Maya', color: const Color(0xFFD81B60));
    final leo = Person(name: 'Leo', color: const Color(0xFF1E88E5));
    List<Map<String, dynamic>> items() => [
      {
        'name': 'Grilled salmon',
        'price': 28,
        'assignments': {maya.clientRef: 100},
      },
      {
        'name': 'Steak frites',
        'price': 34,
        'assignments': {leo.clientRef: 100},
      },
      {
        'name': 'Dessert',
        'price': 60,
        'assignments': {leo.clientRef: 100},
      },
    ];

    testWidgets('uses each saved roster color, not the amount rank', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpParticipants(
          tester,
          savedBill([maya, leo], items()),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(
            tester.element(find.byType(SortedParticipantsCard)),
          ).brightness,
          brightness,
        );
        final avatars =
            tester.widgetList<CircleAvatar>(find.byType(CircleAvatar)).toList();
        expect(avatars.map((a) => a.backgroundColor), [leo.color, maya.color]);
        expect(find.text('Leo · 2'), findsOneWidget);
        expect(find.text('Maya · 1'), findsOneWidget);
        for (final avatar in avatars) {
          expect(
            contrast(
              (avatar.child! as Text).style!.color!,
              avatar.backgroundColor!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness saved avatar ink',
          );
        }
      }
    });

    testWidgets('preserves a single saved roster color', (tester) async {
      final person = Person(name: 'Solo', color: const Color(0xFF82913D));
      await pumpParticipants(tester, savedBill([person], const []));
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        person.color,
      );
      expect(find.text('Solo · 1'), findsOneWidget);
    });

    testWidgets(
      'keeps saved colors when multiple people choose the same color',
      (tester) async {
        const color = Color(0xFF82913D);
        final first = Person(name: 'Alex', color: color);
        final second = Person(name: 'Alex', color: color);
        await pumpParticipants(tester, savedBill([first, second], const []));
        expect(
          tester
              .widgetList<CircleAvatar>(find.byType(CircleAvatar))
              .map((a) => a.backgroundColor),
          [color, color],
        );
        expect(find.text('Alex · 1'), findsOneWidget);
        expect(find.text('Alex · 2'), findsOneWidget);
        expect(first.clientRef, isNot(second.clientRef));
      },
    );

    testWidgets('counts items in plain English', (tester) async {
      await pumpParticipants(tester, savedBill([maya, leo], items()));
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.textContaining('item(s)'), findsNothing);
    });

    testWidgets('chevrons follow the actual expanded row', (tester) async {
      await pumpParticipants(tester, savedBill([maya, leo], items()));
      final row = find.ancestor(
        of: find.text('Maya · 1'),
        matching: find.byType(ExpansionTile),
      );
      final arrow = find.descendant(
        of: row,
        matching: find.byType(AnimatedRotation),
      );
      expect(tester.widget<AnimatedRotation>(arrow).turns, 0);
      expect(find.text('Grilled salmon'), findsNothing);
      await tester.tap(find.text('Maya · 1'));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedRotation>(arrow).turns, .5);
      expect(find.text('Grilled salmon'), findsOneWidget);
      await tester.tap(find.text('Maya · 1'));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedRotation>(arrow).turns, 0);
      expect(find.text('Grilled salmon'), findsNothing);
    });
  });

  group('Person color ink', () {
    testWidgets('every palette color reads on white and on its own row tint', (
      tester,
    ) async {
      useDisplay(tester);
      for (final color in ColorUtils.getParticipantColors()) {
        final person = Person(name: 'Color', color: color);
        await tester.pumpWidget(
          app(
            Column(
              children: [
                PersonCard(
                  key: ValueKey(color),
                  person: person,
                  data: summary(person),
                ),
                assignedCard([person]),
              ],
            ),
          ),
        );
        final amount = find.descendant(
          of: find.byType(PersonCard),
          matching: find.text(r'$25.00'),
        );
        final header = Color.alphaBlend(
          color.withValues(alpha: .1),
          Colors.white,
        );
        expect(
          contrast(textWidget(tester, amount).style!.color!, header),
          greaterThanOrEqualTo(4.5),
          reason: 'summary amount on saved tint $color',
        );
        final percent = textWidget(tester, find.text('100%'));
        final row = ColorUtils.getLightenedColor(color, .92);
        expect(contrast(percent.style!.color!, row), greaterThanOrEqualTo(4.5));
        expect(
          contrast(
            AppTheme.foregroundOn(Colors.white, preferred: color),
            Colors.white,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('keeps ink that already reads', () {
      const ink = Color(0xFF3949AB);
      expect(AppTheme.foregroundOn(Colors.white, preferred: ink), ink);
    });

    testWidgets(
      'avatar ink meets normal text contrast on every palette color',
      (tester) async {
        for (final color in ColorUtils.getParticipantColors()) {
          final person = Person(name: 'Z', color: color);
          await tester.pumpWidget(
            app(
              Column(
                children: [
                  assignedCard([person]),
                  ParticipantAvatar(
                    person: person,
                    isAssigned: false,
                    isSelected: false,
                    isBirthdayPerson: false,
                    onTap: () {},
                    onLongPress: null,
                  ),
                ],
              ),
            ),
          );
          final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
          expect(
            contrast(
              (avatar.child! as Text).style!.color!,
              avatar.backgroundColor!,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'collapsed item stack $color',
          );
          final initial =
              find
                  .descendant(
                    of: find.byType(ParticipantAvatar),
                    matching: find.text('Z'),
                  )
                  .first;
          expect(
            contrast(textWidget(tester, initial).style!.color!, color),
            greaterThanOrEqualTo(4.5),
            reason: 'expanded selector avatar $color',
          );
        }
      },
    );

    test('a shared item never takes one person\'s color', () {
      final roster = people(2);
      expect(ColorUtils.getDominantColor([roster.first]), roster.first.color);
      expect(ColorUtils.getDominantColor(roster), ColorUtils.slateGray);
      expect(
        ColorUtils.getDominantColor(roster.reversed.toList()),
        ColorUtils.slateGray,
      );
      expect(ColorUtils.getDominantColor(const []), ColorUtils.slateGray);
    });
  });

  group('Assignee stack', () {
    testWidgets('shows four people instead of a +1', (tester) async {
      useDisplay(tester);
      await tester.pumpWidget(app(assignedCard(people(4))));
      final avatars = find.byType(CircleAvatar);
      expect(avatars, findsNWidgets(4));
      expect(find.text('+1'), findsNothing);
      final centers = [
        for (var i = 0; i < 4; i++) tester.getCenter(avatars.at(i)).dx,
      ]..sort();
      for (var i = 1; i < centers.length; i++) {
        expect(centers[i] - centers[i - 1], closeTo(20, .01));
      }
      final stack =
          find.ancestor(of: avatars.first, matching: find.byType(Stack)).first;
      for (var i = 0; i < 4; i++) {
        expectInside(tester, avatars.at(i), tester.getRect(stack));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('summarises everyone past four', (tester) async {
      useDisplay(tester);
      await tester.pumpWidget(app(assignedCard(people(5))));
      final avatars = find.byType(CircleAvatar);
      expect(avatars, findsNWidgets(4));
      expect(
        find.descendant(of: avatars, matching: find.text('+2')),
        findsOneWidget,
      );
      for (final label in ['A', 'B', 'C']) {
        expect(
          find.descendant(of: avatars, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: avatars, matching: find.text('D')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Participant visual controls', () {
    testWidgets(
      'four-person selector fits the safe viewport at default text size',
      (tester) async {
        useDisplay(tester);
        final roster = people(4);
        await tester.pumpWidget(
          app(SingleChildScrollView(child: assignedCard(roster))),
        );
        await tester.tap(find.text('Truffle fries'));
        await tester.pumpAndSettle();
        expect(find.byType(ParticipantSelector), findsOneWidget);
        expect(find.byType(ParticipantAvatar), findsNWidgets(4));
        final list = find.descendant(
          of: find.byType(ParticipantSelector),
          matching: find.byType(ListView),
        );
        final scrolling = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)),
        );
        expect(scrolling.position.maxScrollExtent, 0);
        final safe = const Rect.fromLTRB(19, 0, 447, 966);
        for (var i = 0; i < 4; i++) {
          final label = '${i + 1}. ${roster[i].displayName}';
          expect(find.text(label), findsOneWidget);
          expectInside(tester, find.text(label), safe);
          expectInside(tester, find.byType(ParticipantAvatar).at(i), safe);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('custom split rows remain usable at enlarged text size', (
      tester,
    ) async {
      useDisplay(tester, width: 768, height: 1024);
      final roster = people(4);
      final item = BillItem(name: 'Shared meal', price: 20, assignments: {});
      Map<Person, double>? applied;
      await tester.pumpWidget(
        app(
          Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showCustomSplitDialog(
                        context: context,
                        item: item,
                        participants: roster,
                        onAssign: (_, values) => applied = values,
                      ),
                  child: const Text('Split'),
                ),
          ),
          scale: 1.3,
        ),
      );
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      final content = find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 560,
        ),
      );
      expect(content, findsOneWidget);
      expect(tester.getSize(content).width, lessThanOrEqualTo(560));
      final list = find.descendant(of: dialog, matching: find.byType(ListView));
      for (var i = 0; i < 4; i++) {
        final label = find.text('${i + 1}. ${roster[i].displayName}');
        await tester.scrollUntilVisible(
          label,
          100,
          scrollable: find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          ),
        );
        expectInside(tester, label, tester.getRect(dialog));
      }
      await tester.tap(find.text('Apply Split'));
      await tester.pumpAndSettle();
      expect(applied, isNotNull);
      expect(applied!.keys, orderedEquals(roster));
      expect(applied!.values, everyElement(25.0));
      expect(item.price, 20);
      expect(tester.takeException(), isNull);
    });

    testWidgets('summary amount ink changes no recorded values', (
      tester,
    ) async {
      useDisplay(tester);
      final person = Person(name: 'Owner', color: const Color(0xFFFFC107));
      final data = summary(person);
      final before = Map<Person, double>.of(data.items.single.assignments);
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: Column(
              children: [
                BillTotalCard(data: data),
                PersonCard(person: person, data: data),
              ],
            ),
          ),
        ),
      );
      expect(find.text(r'$25.00'), findsNWidgets(2));
      final label = textWidget(tester, find.text('BILL TOTAL'));
      expect(
        contrast(label.style!.color!, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      final amount = textWidget(
        tester,
        find.descendant(
          of: find.byType(PersonCard),
          matching: find.text(r'$25.00'),
        ),
      );
      expect(
        contrast(
          amount.style!.color!,
          Color.alphaBlend(person.color.withValues(alpha: .1), Colors.white),
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(data.total, 25);
      expect(data.subtotal, 20);
      expect(data.tax, 2);
      expect(data.tipAmount, 3);
      expect(data.personShares[person], 25);
      expect(data.items.single.assignments, before);
      expect(data.items.single.name, 'Synthetic meal');
      expect(data.items.single.price, 20);
    });

    testWidgets('auto-added owner keeps saved color with fresh occurrence refs', (
      tester,
    ) async {
      const customColor = Color(0xFF82913D);
      expect(ColorUtils.getParticipantColors(), isNot(contains(customColor)));
      final saved = Person(
        name: 'Owner',
        color: customColor,
        clientRef: 'saved-suggestion-only',
        allocationLabel: 'old allocation',
        participantId: 701,
        memberId: 801,
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      late Directory fixture;
      await tester.runAsync(() async {
        fixture = await Directory.systemTemp.createTemp('billington-ui-owner-');
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => fixture.path);
      addTearDown(() async {
        await DatabaseProvider.db.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await fixture.delete(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        'display_name': '  OWNER  ',
        'auto_add_self': true,
      });
      await tester.runAsync(
        () => DatabaseProvider.db.addPeopleToRecent([saved]),
      );
      final occurrences = <Person>[];
      for (var i = 0; i < 2; i++) {
        await tester.pumpWidget(app(const ParticipantSelectionSheet()));
        // Queue behind the real owned SQLite reads used by the sheet. No
        // production path provider, preferences, API or stored user data is used.
        await tester.runAsync(() async {
          await DatabaseProvider.db.getRecentPeople();
          await DatabaseProvider.db.getSavedGroups();
        });
        await tester.pumpAndSettle();
        final provider = Provider.of<ParticipantsProvider>(
          tester.element(find.byType(AddPersonField)),
          listen: false,
        );
        occurrences.add(provider.participants.single);
        expect(occurrences.last.color, customColor);
        expect(occurrences.last.name, 'OWNER');
        expect(occurrences.last.clientRef, isNot(saved.clientRef));
        expect(occurrences.last.participantId, isNull);
        expect(occurrences.last.memberId, isNull);
        expect(occurrences.last.allocationLabel, 'OWNER');
        await tester.pumpWidget(const SizedBox());
      }
      expect(occurrences.first.clientRef, isNot(occurrences.last.clientRef));
    });
  });
}
