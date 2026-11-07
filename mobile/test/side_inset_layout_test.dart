import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/item_assignment_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_tab_removal_test.dart' show seed;

/// Logical display size and system insets. The side insets reproduce what a
/// native iPhone Duo simulator reported; the layout under test knows no device.
class Display {
  const Display(this.name, this.size, this.inset);
  final String name;
  final Size size;
  final EdgeInsets inset;

  double get safeLeft => inset.left;
  double get safeRight => size.width - inset.right;
}

const rightColumn = Display(
  'status column on the right',
  Size(466, 678),
  EdgeInsets.only(right: 84, bottom: 34),
);
const leftColumn = Display(
  'status column on the left',
  Size(678, 466),
  EdgeInsets.only(left: 84, bottom: 21),
);
const wideRightColumn = Display(
  'wide display with a right status column',
  Size(951, 669),
  EdgeInsets.only(right: 84, bottom: 34),
);
const phone = Display(
  'phone without side insets',
  Size(402, 874),
  EdgeInsets.only(top: 62, bottom: 34),
);
const tablet = Display(
  'tablet without side insets',
  Size(1032, 1376),
  EdgeInsets.only(top: 24, bottom: 20),
);
const insetDisplays = [rightColumn, leftColumn, wideRightColumn];
const plainDisplays = [phone, tablet];

void useDisplay(WidgetTester tester, Display display) {
  const ratio = 3.0;
  final padding = FakeViewPadding(
    left: display.inset.left * ratio,
    top: display.inset.top * ratio,
    right: display.inset.right * ratio,
    bottom: display.inset.bottom * ratio,
  );
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = display.size * ratio;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// flutter_test's font is far wider than the app's. Scaling text to near real
/// metrics keeps these tests failing only on real layout problems.
Widget app(Widget home) => MaterialApp(
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(0.5)),
        child: child!,
      ),
  home: home,
);

/// The scrolling body and every visible text must sit between the display's
/// side insets.
void expectInsideSideInsets(WidgetTester tester, Display display) {
  final lists = find.byType(ListView);
  if (lists.evaluate().isNotEmpty) {
    final list = tester.getRect(lists.first);
    expect(list.left, greaterThanOrEqualTo(display.safeLeft - 0.5));
    expect(list.right, lessThanOrEqualTo(display.safeRight + 0.5));
  }
  final texts = find.byType(Text).evaluate().toList();
  expect(texts, isNotEmpty);
  for (final element in texts) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == element));
    if (rect.width == 0) continue;
    final label = (element.widget as Text).data ?? 'text';
    expect(
      rect.left,
      greaterThanOrEqualTo(display.safeLeft - 0.5),
      reason: '"$label" enters the left inset on ${display.name}',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(display.safeRight + 0.5),
      reason: '"$label" enters the right inset on ${display.name}',
    );
  }
}

List<String> moneyTexts(WidgetTester tester) {
  final money = RegExp(r'^\$\d');
  return find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where(money.hasMatch)
      .toList()
    ..sort();
}

/// Half the $122 subtotal assigned, so the progress bar has a checkable width.
Widget assignmentScreen() {
  final maya = Person(name: 'Maya', color: Colors.teal);
  final leo = Person(name: 'Leo', color: Colors.orange);
  return app(
    ItemAssignmentScreen(
      participants: [maya, leo],
      items: [
        BillItem(name: 'Grilled salmon', price: 61, assignments: {maya: 100}),
        BillItem(name: 'Steak frites', price: 61, assignments: {}),
      ],
      subtotal: 122,
      tax: 10.07,
      tipAmount: 24.40,
      total: 156.47,
      tipPercentage: 20,
      isCustomTipAmount: false,
      currencyCode: 'USD',
    ),
  );
}

Future<void> pumpAssignment(WidgetTester tester, Display display) async {
  useDisplay(tester, display);
  await tester.pumpWidget(assignmentScreen());
  await tester.pumpAndSettle();
}

Finder progressBar() => find.byWidgetPredicate(
  (w) => w is AnimatedContainer && w.constraints?.maxHeight == 6,
);

Future<void> pumpTab(
  WidgetTester tester,
  Display display, {
  bool withBill = true,
}) async {
  useDisplay(tester, display);
  final f = (await tester.runAsync(() => seed()))!;
  addTearDown(f.tabs.dispose);
  addTearDown(f.h.db.close);
  if (!withBill) {
    await tester.runAsync(() => f.tabs.removeBillFromTab(f.tab, f.receipt));
  }
  final tab = await tester.runAsync(() => f.tabs.getTabById(f.tab));
  await tester.pumpWidget(
    app(
      TabDetailScreen(
        tab: tab!,
        tabManager: f.tabs,
        billsManager: f.h.owner,
        apiService: ApiService(
          baseUrl: 'https://synthetic.invalid',
          client: MockClient((_) async => http.Response('{}', 503)),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Assign Items', () {
    for (final display in insetDisplays) {
      testWidgets('keeps text and the progress bar in ${display.name}', (
        tester,
      ) async {
        await pumpAssignment(tester, display);
        expect(find.text('Assigned'), findsOneWidget);
        expectInsideSideInsets(tester, display);

        final bar = tester.getSize(progressBar());
        final track = tester.getSize(
          find.ancestor(of: progressBar(), matching: find.byType(Stack)).first,
        );
        expect(
          track.width,
          lessThanOrEqualTo(display.safeRight - display.safeLeft),
        );
        expect(bar.width, closeTo(track.width / 2, 1));
      });
    }

    for (final display in plainDisplays) {
      testWidgets('keeps the full width on a ${display.name}', (tester) async {
        await pumpAssignment(tester, display);
        final track = tester.getSize(
          find.ancestor(of: progressBar(), matching: find.byType(Stack)).first,
        );
        expect(track.width, display.size.width - 40);
        expect(
          tester.getSize(progressBar()).width,
          closeTo(track.width / 2, 1),
        );
      });
    }

    testWidgets('shows the same amounts with or without side insets', (
      tester,
    ) async {
      await pumpAssignment(tester, phone);
      final plain = moneyTexts(tester);
      await tester.pumpWidget(const SizedBox());
      await pumpAssignment(tester, rightColumn);
      expect(moneyTexts(tester), plain);
      expect(plain, contains(r'$156.47'));
      expect(plain, contains(r'$122.00'));
    });
  });

  group('Enter Bill Details', () {
    final people = [
      Person(name: 'Maya', color: Colors.teal),
      Person(name: 'Leo', color: Colors.orange),
      Person(name: 'Nora', color: Colors.blue),
      Person(name: 'Oliver', color: Colors.pink),
    ];

    for (final display in insetDisplays) {
      testWidgets('keeps the form in ${display.name}', (tester) async {
        useDisplay(tester, display);
        await tester.pumpWidget(app(BillEntryScreen(participants: people)));
        await tester.pumpAndSettle();
        expectInsideSideInsets(tester, display);

        final summary = find.text('BILL SUMMARY');
        await tester.scrollUntilVisible(
          summary,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expectInsideSideInsets(tester, display);
      });
    }

    for (final display in plainDisplays) {
      testWidgets('keeps the full width on a ${display.name}', (tester) async {
        useDisplay(tester, display);
        await tester.pumpWidget(app(BillEntryScreen(participants: people)));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ListView).first).width,
          display.size.width,
        );
      });
    }
  });

  group('Tab detail', () {
    for (final display in insetDisplays) {
      testWidgets('keeps totals and bills in ${display.name}', (tester) async {
        await pumpTab(tester, display);
        expect(find.textContaining('total'), findsOneWidget);
        expectInsideSideInsets(tester, display);
      });

      testWidgets('keeps the empty state in ${display.name}', (tester) async {
        await pumpTab(tester, display, withBill: false);
        expect(find.text('No Bills Yet'), findsOneWidget);
        expectInsideSideInsets(tester, display);
      });
    }

    for (final display in plainDisplays) {
      testWidgets('keeps the full width on a ${display.name}', (tester) async {
        await pumpTab(tester, display);
        expect(
          tester.getSize(find.byType(ListView).first).width,
          display.size.width,
        );
      });
    }
  });
}
