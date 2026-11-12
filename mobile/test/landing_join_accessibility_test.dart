import 'dart:async';
import 'dart:io';

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/landing_screen.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/participant_selection_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/recent_bills_screen.dart';
import 'package:checks_frontend/screens/settings/settings_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/screens/tabs/tabs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Flutter 3.41.5's iOS embedder, FlutterViewController.mm textScaleFactor:
// https://github.com/flutter/flutter/blob/2c9eb20739/engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController.mm#L2288-L2341
// Every content-size category from the default through accessibility XXXL.
const _bodySizes = [17, 19, 21, 23, 28, 33, 40, 47, 53];
const _invite = 'https://billingtonapp.vercel.app/t/19?t=synthetic-invite';
const _displays = [
  // iOS minimum is 15.5, so the first-generation SE is still supported.
  (name: 'iPhone SE', size: Size(320, 568), top: 20.0, bottom: 0.0),
  (name: 'iPhone 17e', size: Size(390, 844), top: 47.0, bottom: 34.0),
];

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

// Hold the join at the existing manager seam: this proves the sheet hands off
// the entered URL/name without rendering the next, unrelated tab-detail flow.
class _JoiningTabs extends TabManager {
  _JoiningTabs()
    : super.withDependencies(
        database: DatabaseProvider.db,
        receipts: RecentBillsManager(),
      );

  final pending = Completer<AppTab?>();
  final calls = <(String, String)>[];

  @override
  Future<AppTab?> joinTab(String shareUrl, String displayName) {
    calls.add((shareUrl, displayName));
    return pending.future;
  }
}

Future<void> _show(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  // Let the focused field finish its caret/keyboard scroll before the user scroll.
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory fixture;

  setUpAll(() async {
    fixture = await Directory.systemTemp.createTemp('L13-accessibility-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => fixture.path);
    // Open the real, empty local store outside the widget-test fake clock.
    await DatabaseProvider.db.getAllTabs();
  });
  tearDownAll(() async {
    await DatabaseProvider.db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await fixture.delete(recursive: true);
  });

  for (final display in _displays) {
    for (final bodySize in _bodySizes) {
      final scale = bodySize / 17;
      final suffix = '${display.name} iOS body $bodySize';

      Future<_Routes> pump(WidgetTester tester, Widget home) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = display.size;
        tester.view.padding = FakeViewPadding(
          top: display.top,
          bottom: display.bottom,
        );
        tester.view.viewPadding = FakeViewPadding(
          top: display.top,
          bottom: display.bottom,
        );
        addTearDown(() {
          tester.view.reset();
        });
        final routes = _Routes();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
            navigatorObservers: [routes],
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: home,
          ),
        );
        await tester.runAsync(() => DatabaseProvider.db.getAllTabs());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return routes;
      }

      testWidgets('Landing controls remain reachable $suffix', (tester) async {
        final routes = await pump(tester, const LandingScreen());
        final context = tester.element(find.byType(LandingScreen));
        final controls = <Finder, Matcher>{
          find.byTooltip('Settings'): isA<SettingsScreen>(),
          find.text('Quick Split'): isA<FractionallySizedBox>().having(
            (box) => box.child,
            'participant sheet',
            isA<ParticipantSelectionSheet>(),
          ),
          find.text("I'm Lazy"): isA<BillEntryScreen>().having(
            (screen) => screen.lazyMode,
            'lazy mode',
            isTrue,
          ),
          find.text('Tabs'): isA<TabsScreen>(),
          find.text('Recent Bills'): isA<RecentBillsScreen>(),
        };
        for (final entry in controls.entries) {
          await _show(tester, entry.key);
          final count = routes.pushed.length;
          await tester.tap(entry.key);
          expect(routes.pushed, hasLength(count + 1));
          final route = routes.pushed.last;
          final Widget destination;
          if (route is MaterialPageRoute) {
            destination = route.builder(context);
          } else {
            destination = (route as ModalBottomSheetRoute).builder(context);
          }
          expect(destination, entry.value);
          // Verify the real tap and destination without rendering other flows,
          // whose large-text layouts belong to their own tickets.
          route.navigator!.removeRoute(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });

      for (final fromInvite in [false, true]) {
        testWidgets(
          'Join ${fromInvite ? 'invite' : 'toolbar'} controls remain reachable $suffix',
          (tester) async {
            final tabs = _JoiningTabs();
            addTearDown(tabs.dispose);
            await pump(
              tester,
              TabsScreen(
                initialInviteUrl: fromInvite ? _invite : null,
                tabManager: tabs,
              ),
            );
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('display_name', 'Synthetic Friend');
            if (!fromInvite) {
              await tester.tap(find.byTooltip('Join Tab'));
              await tester.pumpAndSettle();
            }
            expect(find.text('Join a Tab'), findsOneWidget);
            expect(tester.takeException(), isNull);
            final field = find.byType(TextFormField);
            final editable = tester.widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            );
            expect(editable.controller.text, fromInvite ? _invite : '');

            // Cover both the full screen and the constrained keyboard viewport.
            for (final keyboard in [0.0, 300.0]) {
              tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
              await tester.pumpAndSettle();
              await _show(tester, find.text('Join a Tab'));
              await _show(tester, field);
              await tester.tap(field);
              await tester.enterText(field, 'invalid');
              await _show(
                tester,
                find.widgetWithText(FilledButton, 'Join Tab'),
              );
              await tester.tap(find.widgetWithText(FilledButton, 'Join Tab'));
              await tester.pumpAndSettle();
              expect(find.text('Join a Tab'), findsOneWidget);
              expect(tabs.calls, isEmpty);
              expect(
                find.text('Please enter a valid Billington link'),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            }

            await _show(tester, field);
            await tester.enterText(field, _invite);
            await _show(tester, find.widgetWithText(FilledButton, 'Join Tab'));
            await tester.tap(find.widgetWithText(FilledButton, 'Join Tab'));
            // Dismissing the focused sheet also dismisses the native keyboard.
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            expect(find.text('Join a Tab'), findsNothing);
            expect(tabs.calls, [(_invite, 'Synthetic Friend')]);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            tabs.pending.complete(null);
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
