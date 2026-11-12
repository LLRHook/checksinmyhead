import 'dart:math' as math;
import 'dart:ui' as ui show SemanticsAction, Tristate;

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/screens/settings/payment_method_sheet.dart';
import 'package:checks_frontend/screens/settings/settings_screen.dart';
import 'package:checks_frontend/screens/settings/widgets/color_picker_sheet.dart';
import 'package:checks_frontend/screens/settings/widgets/payment_method_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only spy at shared_preferences' existing, locked platform seam. The app
// still calls its real PreferencesService; no production dependency is added.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// Independent expected palette contract, including the existing stored values.
const _presets = <String, Color>{
  'Teal (default) accent color': Color(0xFF328983),
  'Blue accent color': Color(0xFF2196F3),
  'Purple accent color': Color(0xFF9C27B0),
  'Pink accent color': Color(0xFFE91E63),
  'Deep Orange accent color': Color(0xFFFF5722),
  'Green accent color': Color(0xFF4CAF50),
  'Blue Grey accent color': Color(0xFF607D8B),
  'Brown accent color': Color(0xFF795548),
  'Black accent color': Color(0xFF000000),
};
const _customLabel = 'Custom accent color';
const _brightCustom = Color(0xFFFFF8C0);
const _darkCustom = Color(0xFF101820);

class _PreferencesSpy extends InMemorySharedPreferencesStore {
  _PreferencesSpy(Map<String, Object> seed)
    : super.withData({
        for (final entry in seed.entries) 'flutter.${entry.key}': entry.value,
      });

  final writes = <({String method, String key, Object? value})>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writes.add((method: 'set$valueType', key: key, value: value));
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes.add((method: 'remove', key: key, value: null));
    return super.remove(key);
  }
}

Future<void> _withSettings(
  WidgetTester tester, {
  double width = 320,
  bool dark = false,
  Color accent = AppTheme.defaultPrimary,
  double textScale = 1,
  bool populated = false,
  required Future<void> Function(
    _PreferencesSpy store,
    List<MethodCall> haptics,
  )
  body,
}) async {
  final previousAccent = AppTheme.primaryColorNotifier.value;
  final previousPlatform = debugDefaultTargetPlatformOverride;
  final previousStore = SharedPreferencesStorePlatform.instance;
  final messenger = tester.binding.defaultBinaryMessenger;
  final haptics = <MethodCall>[];
  final seed = <String, Object>{
    if (accent != AppTheme.defaultPrimary) 'accent_color': accent.toARGB32(),
    if (populated) ...{
      'display_name': 'Synthetic Friend',
      'selectedPayments': <String>['Venmo'],
      'payment_Venmo': 'synthetic-friend@example.invalid',
    },
  };
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(seed);
  final store = _PreferencesSpy(seed);
  SharedPreferencesStorePlatform.instance = store;
  AppTheme.setPrimaryColor(accent);
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    // Model framework capability reads locally; never inspect the host clipboard.
    // Keep unexpected platform effects failing rather than accepting all methods.
    switch (call.method) {
      case 'SystemChrome.setSystemUIOverlayStyle':
      case 'SystemChrome.setApplicationSwitcherDescription':
        return null;
      case 'LiveText.isLiveTextInputAvailable':
        return false;
      case 'Clipboard.hasStrings':
        return <String, bool>{'value': false};
      case 'HapticFeedback.vibrate':
        haptics.add(call);
        return null;
      default:
        throw TestFailure('Unexpected platform effect: ${call.method}');
    }
  });
  final semantics = tester.ensureSemantics();
  try {
    await tester.pumpWidget(
      ValueListenableBuilder<Color>(
        valueListenable: AppTheme.primaryColorNotifier,
        builder:
            (context, _, child) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
              home: const SettingsScreen(),
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Your Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await body(store, haptics);
    expect(tester.takeException(), isNull);
  } finally {
    // Dispose before the test body returns: no late addTearDown semantics leak.
    try {
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = previousPlatform;
      AppTheme.setPrimaryColor(previousAccent);
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  }
}

Finder _choice(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Future<void> _checkGuidelines(WidgetTester tester, String region) async {
  // Evaluate every pinned guideline even when one fails; retain all reasons.
  final failures = <String>[];
  for (final entry
      in <String, AccessibilityGuideline>{
        'labels': labeledTapTargetGuideline,
        'iOS 44-point targets': iOSTapTargetGuideline,
        'text contrast': textContrastGuideline,
      }.entries) {
    final result = await entry.value.evaluate(tester);
    if (!result.passed) failures.add('${entry.key}: ${result.reason}');
  }
  expect(failures, isEmpty, reason: '$region\n${failures.join('\n')}');
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _expectChoices(
  WidgetTester tester, {
  required String selected,
}) async {
  await _show(tester, find.text('App Color'));
  final rectangles = <Rect>[];
  for (final label in [..._presets.keys, _customLabel]) {
    final finder = _choice(label);
    expect(finder, findsOneWidget);
    final node = tester.getSemantics(finder);
    final data = node.getSemanticsData();
    expect(data.label, label);
    expect(data.flagsCollection.isButton, isTrue, reason: label);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue, reason: label);
    expect(
      data.flagsCollection.isSelected,
      label == selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
      reason: label,
    );
    final rect = tester.getRect(finder);
    expect(rect.width, greaterThanOrEqualTo(48), reason: label);
    expect(rect.height, greaterThanOrEqualTo(48), reason: label);
    expect(node.rect.width, greaterThanOrEqualTo(44), reason: label);
    expect(node.rect.height, greaterThanOrEqualTo(44), reason: label);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(tester.view.physicalSize.width));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    for (final other in rectangles) {
      expect(rect.overlaps(other), isFalse, reason: 'Overlapping $label');
    }
    rectangles.add(rect);
  }
}

void _semanticTap(WidgetTester tester, Finder finder) {
  final node = tester.getSemantics(finder);
  node.owner!.performAction(node.id, ui.SemanticsAction.tap);
}

void _expectSelectedCheck(WidgetTester tester, String label, Color color) {
  final check = find.descendant(
    of: _choice(label),
    matching: find.byIcon(Icons.check),
  );
  expect(check, findsOneWidget);
  final swatch = tester.widget<Container>(
    find.descendant(of: _choice(label), matching: find.byType(Container)).first,
  );
  expect((swatch.decoration! as BoxDecoration).color, color);
  final ink = tester.widget<Icon>(check).color!;
  // Validate actual selected widget output against the non-text contrast
  // requirement, without calling the production foreground selector.
  final lighter = math.max(ink.computeLuminance(), color.computeLuminance());
  final darker = math.min(ink.computeLuminance(), color.computeLuminance());
  expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(3));
}

void main() {
  for (final width in <double>[320, 390]) {
    for (final dark in [false, true]) {
      for (final accent
          in <String, Color>{
            'default': AppTheme.defaultPrimary,
            'purple preset': _presets['Purple accent color']!,
            'bright custom': _brightCustom,
            'dark custom': _darkCustom,
          }.entries) {
        testWidgets(
          'Settings guidelines ${width.toInt()} ${dark ? 'dark' : 'light'} ${accent.key}',
          (tester) async {
            await _withSettings(
              tester,
              width: width,
              dark: dark,
              accent: accent.value,
              body: (store, haptics) async {
                await _checkGuidelines(tester, 'top');
                await _show(tester, find.text('Payment Options'));
                await _checkGuidelines(tester, 'payment button');
                final selected = _presets.entries
                    .where((e) => e.value == accent.value)
                    .map((e) => e.key);
                await _expectChoices(
                  tester,
                  selected: selected.isEmpty ? _customLabel : selected.single,
                );
                await _checkGuidelines(tester, 'App Color');
                await _show(tester, find.text('Privacy & Data'));
                await tester.tap(find.text('Privacy & Data'));
                await tester.pumpAndSettle();
                await _checkGuidelines(tester, 'expanded privacy');
                await _show(tester, find.text('Read the full privacy policy'));
                await _checkGuidelines(tester, 'privacy link');
                await _show(tester, find.text('Contact Us'));
                await _checkGuidelines(tester, 'support');
                await _show(tester, find.text('Version 2.0.11'));
                await _checkGuidelines(tester, 'footer');
                expect(store.writes, isEmpty);
                expect(haptics, isEmpty);
                expect(AppTheme.primaryColorNotifier.value, accent.value);
              },
            );
          },
        );
      }

      testWidgets(
        'Settings wraps at 2x text ${width.toInt()} ${dark ? 'dark' : 'light'}',
        (tester) async {
          await _withSettings(
            tester,
            width: width,
            dark: dark,
            textScale: 2,
            body: (store, haptics) async {
              for (final label in [
                'Made by a few friends tired of using\nspreadsheets to split the bill.',
                'Used when creating or joining shared tabs.',
                'Auto-add me to bills',
                'Automatically add yourself as a participant',
                'Show bill totals in USD',
                'Receipt details stay in their original currency. Trips keep their own setting.',
                'Payment Options',
                'Add Payment Methods',
                'Privacy & Data',
                'Rate Us on App Store',
                'Share with Friends',
              ]) {
                final finder = find.text(label);
                await _show(tester, finder);
                final text = tester.widget<Text>(finder);
                expect(text.softWrap, isNot(false), reason: label);
                expect(text.maxLines, isNull, reason: label);
                final paragraph = tester.renderObject<RenderParagraph>(finder);
                expect(paragraph.didExceedMaxLines, isFalse, reason: label);
                final rect = tester.getRect(finder);
                expect(rect.left, greaterThanOrEqualTo(0), reason: label);
                expect(rect.right, lessThanOrEqualTo(width), reason: label);
                expect(tester.takeException(), isNull, reason: label);
              }
              await _expectChoices(
                tester,
                selected: 'Teal (default) accent color',
              );
              await _checkGuidelines(tester, 'large-text colors');
              await _show(tester, find.text('Privacy & Data'));
              await tester.tap(find.text('Privacy & Data'));
              await tester.pumpAndSettle();
              await _show(tester, find.text('Read the full privacy policy'));
              await _checkGuidelines(tester, 'large-text privacy action');
              expect(store.writes, isEmpty);
            },
          );
        },
      );

      testWidgets(
        'Settings populated payment row ${width.toInt()} ${dark ? 'dark' : 'light'}',
        (tester) async {
          await _withSettings(
            tester,
            width: width,
            dark: dark,
            accent: dark ? _darkCustom : _brightCustom,
            populated: true,
            body: (store, haptics) async {
              await _show(tester, find.text('Venmo'));
              final row = tester.widget<PaymentMethodItem>(
                find.byType(PaymentMethodItem),
              );
              expect(row.foregroundColor, isNotNull);
              expect(find.byTooltip('Venmo options'), findsOneWidget);
              final options =
                  tester
                      .getSemantics(find.byTooltip('Venmo options'))
                      .getSemanticsData();
              expect(options.flagsCollection.isButton, isTrue);
              expect(options.hasAction(ui.SemanticsAction.tap), isTrue);
              expect(
                '${options.label} ${options.tooltip}',
                contains('Venmo options'),
              );
              expect(
                '${options.label} ${options.tooltip}',
                isNot(contains(row.identifier)),
              );
              await _checkGuidelines(tester, 'populated payments');
              await _show(tester, find.text('Edit Payment Methods'));
              await _checkGuidelines(tester, 'populated payment action');
              await _show(tester, find.text('Venmo'));
              await tester.tap(find.text('Venmo'));
              await tester.pumpAndSettle();
              expect(find.byType(PaymentMethodSheet), findsOneWidget);
              final sheet = tester.widget<PaymentMethodSheet>(
                find.byType(PaymentMethodSheet),
              );
              expect(sheet.initialSelectedMethods, ['Venmo']);
              expect(
                sheet.initialIdentifiers['Venmo'],
                'synthetic-friend@example.invalid',
              );
              Navigator.of(
                tester.element(find.byType(PaymentMethodSheet)),
              ).pop();
              await tester.pumpAndSettle();
              expect(store.writes, isEmpty);
              expect(haptics, isEmpty);
              await _show(tester, find.byTooltip('Venmo options'));
              _semanticTap(tester, find.byTooltip('Venmo options'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Edit'));
              await tester.pumpAndSettle();
              expect(find.byType(PaymentMethodSheet), findsOneWidget);
              Navigator.of(
                tester.element(find.byType(PaymentMethodSheet)),
              ).pop();
              await tester.pumpAndSettle();
              expect(store.writes, isEmpty);
              await _show(tester, find.byTooltip('Venmo options'));
              await tester.tap(find.byTooltip('Venmo options'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Delete'));
              await tester.pumpAndSettle();
              final saves = store.writes.where(
                (write) => write.key == 'flutter.selectedPayments',
              );
              expect(saves, hasLength(1));
              expect(saves.single.value, isEmpty);
              expect(haptics, hasLength(1));
              expect(
                haptics.single.arguments,
                'HapticFeedbackType.selectionClick',
              );
              expect(find.byType(PaymentMethodItem), findsNothing);
              expect(find.text('Add Payment Methods'), findsOneWidget);
              final preferences = await SharedPreferences.getInstance();
              expect(preferences.getStringList('selectedPayments'), isEmpty);
              expect(preferences.getString('payment_Venmo'), isNull);
            },
          );
        },
      );
    }
  }

  for (final semantic in [false, true]) {
    testWidgets(
      'Accent ${semantic ? 'semantic' : 'physical'} tap saves and notifies once',
      (tester) async {
        await _withSettings(
          tester,
          body: (store, haptics) async {
            var notifications = 0;
            void changed() => notifications++;
            AppTheme.primaryColorNotifier.addListener(changed);
            try {
              final blue = _choice('Blue accent color');
              await _show(tester, blue);
              if (semantic) {
                _semanticTap(tester, blue);
              } else {
                await tester.tap(blue);
              }
              await tester.pumpAndSettle();
              expect(store.writes, [
                (
                  method: 'setInt',
                  key: 'flutter.accent_color',
                  value: 0xFF2196F3,
                ),
              ]);
              expect(
                (await SharedPreferences.getInstance()).getInt('accent_color'),
                0xFF2196F3,
              );
              expect(notifications, 1);
              expect(haptics, hasLength(1));
              expect(
                haptics.single.arguments,
                'HapticFeedbackType.selectionClick',
              );
              await _expectChoices(tester, selected: 'Blue accent color');
            } finally {
              AppTheme.primaryColorNotifier.removeListener(changed);
            }
          },
        );
      },
    );
  }

  for (final color in [
    _brightCustom,
    _darkCustom,
    _presets['Blue accent color']!,
  ]) {
    testWidgets('Custom hex ${color.toARGB32().toRadixString(16)} saves once', (
      tester,
    ) async {
      await _withSettings(
        tester,
        body: (store, haptics) async {
          var notifications = 0;
          void changed() => notifications++;
          AppTheme.primaryColorNotifier.addListener(changed);
          try {
            await _show(tester, _choice(_customLabel));
            await tester.tap(_choice(_customLabel));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Enter hex code'));
            await tester.pumpAndSettle();
            final hex =
                color.toARGB32().toRadixString(16).substring(2).toUpperCase();
            await tester.enterText(
              find.descendant(
                of: find.byType(ColorPickerSheet),
                matching: find.byType(TextField),
              ),
              hex,
            );
            await tester.tap(find.text('Apply'));
            await tester.pumpAndSettle();
            expect(find.byType(ColorPickerSheet), findsNothing);
            expect(store.writes, [
              (
                method: 'setInt',
                key: 'flutter.accent_color',
                value: color.toARGB32(),
              ),
            ]);
            expect(notifications, 1);
            expect(AppTheme.primaryColorNotifier.value, color);
            expect(haptics.map((call) => call.arguments), [
              'HapticFeedbackType.mediumImpact',
              'HapticFeedbackType.selectionClick',
            ]);
            await _expectChoices(tester, selected: _customLabel);
            _expectSelectedCheck(tester, _customLabel, color);
            expect(
              tester
                  .getSemantics(_choice(_customLabel))
                  .getSemanticsData()
                  .value,
              '#$hex',
            );
          } finally {
            AppTheme.primaryColorNotifier.removeListener(changed);
          }
        },
      );
    });
  }

  testWidgets('Every existing preset persists and default resets its key', (
    tester,
  ) async {
    await _withSettings(
      tester,
      accent: _brightCustom,
      body: (store, haptics) async {
        for (final entry in _presets.entries) {
          store.writes.clear();
          haptics.clear();
          await _show(tester, _choice(entry.key));
          await tester.tap(_choice(entry.key));
          await tester.pumpAndSettle();
          expect(store.writes, hasLength(1), reason: entry.key);
          expect(store.writes.single.key, 'flutter.accent_color');
          final prefs = await SharedPreferences.getInstance();
          if (entry.value == AppTheme.defaultPrimary) {
            expect(store.writes.single.method, 'remove');
            expect(prefs.containsKey('accent_color'), isFalse);
          } else {
            expect(store.writes.single.method, 'setInt');
            expect(prefs.getInt('accent_color'), entry.value.toARGB32());
          }
          expect(AppTheme.primaryColorNotifier.value, entry.value);
          expect(haptics, hasLength(1));
          await _expectChoices(tester, selected: entry.key);
          _expectSelectedCheck(tester, entry.key, entry.value);
        }
      },
    );
  });

  for (final semantic in [false, true]) {
    testWidgets('Custom picker reachable by ${semantic ? 'semantics' : 'tap'}', (
      tester,
    ) async {
      await _withSettings(
        tester,
        body: (store, haptics) async {
          final custom = _choice(_customLabel);
          await _show(tester, custom);
          if (semantic) {
            _semanticTap(tester, custom);
          } else {
            await tester.tap(custom);
          }
          await tester.pumpAndSettle();
          expect(find.byType(ColorPickerSheet), findsOneWidget);
          expect(find.text('Custom Color'), findsOneWidget);
          // Reachability exercises the real modal and its existing picker. Its
          // separate internal wheel/hex accessibility is not this patch's scope.
          expect(store.writes, isEmpty);
          Navigator.of(tester.element(find.byType(ColorPickerSheet))).pop();
          await tester.pumpAndSettle();
          expect(find.byType(ColorPickerSheet), findsNothing);
        },
      );
    });
  }

  testWidgets('Payment options and row invoke each existing callback once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    var edits = 0;
    var deletes = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: PaymentMethodItem(
              methodName: 'Venmo',
              identifier: 'synthetic@example.invalid',
              foregroundColor: Colors.black,
              onTap: () => taps++,
              onEdit: () => edits++,
              onDelete: () => deletes++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _checkGuidelines(tester, 'isolated payment row');
      await tester.tap(find.text('Venmo'));
      expect([taps, edits, deletes], [1, 0, 0]);
      _semanticTap(tester, find.byTooltip('Venmo options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect([taps, edits, deletes], [1, 0, 0]);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect([taps, edits, deletes], [1, 1, 0]);
      await tester.tap(find.byTooltip('Venmo options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect([taps, edits, deletes], [1, 1, 1]);
      final swipe = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(swipe.direction, DismissDirection.endToStart);
      expect(swipe.confirmDismiss, isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    }
  });

  // The in-app notice must agree with the maintained /privacy-policy page: it
  // may not promise that uninstalling removes data or limit online storage to
  // bills the user chose to share.
  testWidgets(
    'Privacy notice discloses online storage without an uninstall promise',
    (tester) async {
      await _withSettings(
        tester,
        textScale: 2,
        body: (store, haptics) async {
          await _show(tester, find.text('Privacy & Data'));
          await tester.tap(find.text('Privacy & Data'));
          await tester.pumpAndSettle();
          final notice = find.textContaining('Billington has no accounts');
          await _show(tester, notice);
          final text = tester.widget<Text>(notice).data!;
          expect(text, contains('Saving a bill or creating a tab can send it'));
          expect(text, contains('stores it online'));
          expect(text, contains('Receipt scans are sent to Anthropic'));
          expect(text, contains('does not delete online bills or tabs'));
          expect(
            text,
            isNot(
              matches(
                RegExp(
                  r'removed when|never leaves|zero cloud|shared data is not',
                  caseSensitive: false,
                ),
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(notice);
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = tester.getRect(notice);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          await _checkGuidelines(tester, 'large-text privacy notice');
          expect(store.writes, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
