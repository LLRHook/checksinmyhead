import 'dart:convert';

import 'package:checks_frontend/services/version_policy_service.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
