import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures tab invites arriving while the app is cold or already open.
/// Invites are stored until the user successfully joins the tab.
class InviteLinkService {
  static const _pendingInviteKey = 'pending_tab_invite';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _storeIfTabInvite(initialUri);
    } catch (_) {
      // Link intake is optional; manual join remains available.
    }

    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _storeIfTabInvite(uri);
    });
  }

  Future<String?> getPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingInviteKey);
  }

  Future<void> clearPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteKey);
  }

  Future<void> _storeIfTabInvite(Uri uri) async {
    final normalized = _normalize(uri);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteKey, normalized);
  }

  String? _normalize(Uri uri) {
    if (uri.scheme == 'https' &&
        (uri.host == 'billingtonapp.vercel.app' ||
            uri.host == 'billington.app') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 't' &&
        uri.queryParameters['t']?.isNotEmpty == true) {
      return uri.toString();
    }

    if (uri.scheme == 'billington' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'tab' &&
        uri.queryParameters['t']?.isNotEmpty == true) {
      return Uri.https(
        'billingtonapp.vercel.app',
        '/t/${uri.pathSegments[1]}',
        {'t': uri.queryParameters['t']!},
      ).toString();
    }

    return null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
