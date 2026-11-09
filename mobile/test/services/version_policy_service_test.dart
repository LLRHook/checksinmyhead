import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/screens/onboarding/onboarding_screen.dart';
import 'package:checks_frontend/screens/splash_screen.dart';
import 'package:checks_frontend/screens/update_required_screen.dart';
import 'package:checks_frontend/services/version_policy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('VersionPolicyService.compareVersions', () {
    test('compares numeric segments, not strings', () {
      expect(
        VersionPolicyService.compareVersions('2.10.0', '2.9.9'),
        greaterThan(0),
      );
      expect(VersionPolicyService.compareVersions('2.0.3', '2.0.3'), 0);
      expect(
        VersionPolicyService.compareVersions('1.9.9', '2.0.0'),
        lessThan(0),
      );
    });

    test('does not block on malformed versions', () {
      expect(VersionPolicyService.compareVersions('unknown', '2.0.0'), 0);
    });
  });

  test('blocks only when policy minimum is newer than installed app', () async {
    final service = VersionPolicyService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/app/version-policy');
        return http.Response(
          jsonEncode({'minimum_supported_version': '2.1.0'}),
          200,
        );
      }),
    );

    expect(await service.isUpdateRequired(installedVersion: '2.0.9'), isTrue);
    expect(await service.isUpdateRequired(installedVersion: '2.1.0'), isFalse);
  });

  test('accepts only trusted App Store destinations from the policy', () async {
    final service = VersionPolicyService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'minimum_supported_version': '2.1.0',
            'store_url': 'https://attacker.example/fake-update',
          }),
          200,
        ),
      ),
    );

    final decision = await service.check(installedVersion: '2.0.0');
    expect(decision.updateRequired, isTrue);
    expect(decision.storeUrl, VersionPolicyService.appStoreUrl);
  });

  test('fails open when policy cannot be fetched', () async {
    final service = VersionPolicyService(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    expect(await service.isUpdateRequired(installedVersion: '1.0.0'), isFalse);
  });

  group('policy outage fails open', () {
    Future<VersionPolicyDecision> checkWith(
      Future<http.Response> Function(http.Request request) handler,
    ) => VersionPolicyService(
      client: MockClient(handler),
    ).check(installedVersion: '1.0.0');

    void expectAllowed(VersionPolicyDecision decision) {
      expect(decision.updateRequired, isFalse);
      expect(decision.storeUrl, VersionPolicyService.appStoreUrl);
    }

    test('every non-200 policy status allows the app to continue', () async {
      for (final status in [301, 400, 401, 403, 404, 426, 429, 500, 502, 504]) {
        expectAllowed(
          await checkWith(
            (_) async => http.Response(
              jsonEncode({'minimum_supported_version': '9.0.0'}),
              status,
            ),
          ),
        );
      }
    });

    test('transport failures allow the app to continue', () async {
      expectAllowed(
        await checkWith((_) async => throw const SocketException('offline')),
      );
      expectAllowed(
        await checkWith((_) async => throw http.ClientException('reset')),
      );
      expectAllowed(
        await checkWith(
          (_) async => throw const HandshakeException('certificate'),
        ),
      );
    });

    test('unusable policy bodies allow the app to continue', () async {
      for (final body in [
        '',
        'not json',
        'null',
        '[]',
        '"9.0.0"',
        '{}',
        '{"minimum_supported_version":null}',
        '{"minimum_supported_version":9}',
        '{"minimum_supported_version":"9.0"}',
        '{"minimum_supported_version":"9.0.0-beta"}',
        '{"minimum_supported_version":"latest"}',
        '{"minimum_supported_version":"9.-1.0"}',
      ]) {
        expectAllowed(await checkWith((_) async => http.Response(body, 200)));
      }
    });

    testWidgets('a policy request that never answers times out open', (
      tester,
    ) async {
      final decision = checkWith((_) => Completer<http.Response>().future);
      var settled = false;
      unawaited(decision.then((_) => settled = true));

      await tester.pump(
        VersionPolicyService.timeout - const Duration(milliseconds: 1),
      );
      expect(settled, isFalse);
      await tester.pump(const Duration(milliseconds: 2));
      expect(settled, isTrue);
      expectAllowed(await decision);
    });

    test('the non-blocking server minimum never requires an update', () async {
      for (final installed in ['0.0.0', '1.4.0', '2.0.11']) {
        final service = VersionPolicyService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'minimum_supported_version': '0.0.0'}),
              200,
            ),
          ),
        );
        expect(
          await service.isUpdateRequired(installedVersion: installed),
          isFalse,
        );
      }
    });

    testWidgets('startup continues past the splash during a policy outage', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            versionPolicyFuture: checkWith(
              (_) async => http.Response('unavailable', 503),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(UpdateRequiredScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('startup still blocks when a reachable policy requires it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            versionPolicyFuture: checkWith(
              (_) async => http.Response(
                jsonEncode({'minimum_supported_version': '9.0.0'}),
                200,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
