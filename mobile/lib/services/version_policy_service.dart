import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'api_config.dart';

class VersionPolicyDecision {
  const VersionPolicyDecision({
    required this.updateRequired,
    required this.storeUrl,
  });

  final bool updateRequired;
  final String storeUrl;
}

class VersionPolicyService {
  VersionPolicyService({http.Client? client})
    : _client = client ?? http.Client();

  static const timeout = Duration(seconds: 2);
  static const appStoreUrl = 'https://apps.apple.com/app/id6746379502';

  final http.Client _client;

  Future<VersionPolicyDecision> check({String? installedVersion}) async {
    try {
      final version =
          installedVersion ?? (await PackageInfo.fromPlatform()).version;
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/app/version-policy'))
          .timeout(timeout);
      if (response.statusCode != 200) return _allow();

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _allow();
      final minimum = decoded['minimum_supported_version'];
      if (minimum is! String || _parseStableVersion(minimum) == null) {
        return _allow();
      }
      return VersionPolicyDecision(
        updateRequired: compareVersions(version, minimum) < 0,
        storeUrl: _validatedStoreUrl(decoded['store_url']),
      );
    } catch (_) {
      // A temporary policy outage must never strand users outside the app.
      return _allow();
    }
  }

  Future<bool> isUpdateRequired({String? installedVersion}) async =>
      (await check(installedVersion: installedVersion)).updateRequired;

  static VersionPolicyDecision _allow() =>
      const VersionPolicyDecision(updateRequired: false, storeUrl: appStoreUrl);

  static String _validatedStoreUrl(Object? value) {
    if (value is! String) return appStoreUrl;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'apps.apple.com', 'play.google.com'}.contains(uri.host)) {
      return appStoreUrl;
    }
    return uri.toString();
  }

  static int compareVersions(String left, String right) {
    final leftParts = _parseStableVersion(left);
    final rightParts = _parseStableVersion(right);
    if (leftParts == null || rightParts == null) return 0;
    for (var index = 0; index < 3; index++) {
      final comparison = leftParts[index].compareTo(rightParts[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static List<int>? _parseStableVersion(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final parsed = parts.map(int.tryParse).toList();
    if (parsed.any((part) => part == null || part < 0)) return null;
    return parsed.cast<int>();
  }
}
