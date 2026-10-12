import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures shared bill and trip links while the app is cold or already open.
/// Links are retained locally until their destination screen is opened.
class InviteLinkService {
  static const _pendingInviteKey = 'pending_tab_invite';
  static final ValueNotifier<String?> pendingShareLink = ValueNotifier(null);

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _storeIfShareLink(initialUri);
    } catch (_) {
      // Link intake is optional; manual join remains available.
    }

    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _storeIfShareLink(uri);
    });
  }

  Future<String?> getPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingInviteKey);
  }

  Future<void> clearPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteKey);
    pendingShareLink.value = null;
  }

  Future<void> _storeIfShareLink(Uri uri) async {
    final normalized = normalizeShareLink(uri);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteKey, normalized);
    pendingShareLink.value = normalized;
  }

  static String? normalizeShareLink(Uri uri) {
    if (uri.scheme == 'https' &&
        (uri.host == 'billingtonapp.vercel.app' ||
            uri.host == 'billington.app') &&
        uri.pathSegments.length >= 2 &&
        (uri.pathSegments.first == 't' || uri.pathSegments.first == 'b') &&
        uri.queryParameters['t']?.isNotEmpty == true) {
      return uri.toString();
    }

    if (uri.scheme == 'billington' &&
        (uri.host == 'tab' || uri.host == 'bill') &&
        uri.pathSegments.isNotEmpty &&
        uri.queryParameters['t']?.isNotEmpty == true) {
      final route = uri.host == 'tab' ? 't' : 'b';
      return Uri.https(
        'billingtonapp.vercel.app',
        '/$route/${uri.pathSegments.first}',
        {'t': uri.queryParameters['t']!},
      ).toString();
    }

    // Also accept the older path-style custom scheme, such as
    // billington:///tab/19?t=... or billington:///bill/27?t=...
    if (uri.scheme == 'billington' &&
        uri.pathSegments.length >= 2 &&
        (uri.pathSegments.first == 'tab' || uri.pathSegments.first == 'bill') &&
        uri.queryParameters['t']?.isNotEmpty == true) {
      final route = uri.pathSegments.first == 'tab' ? 't' : 'b';
      return Uri.https(
        'billingtonapp.vercel.app',
        '/$route/${uri.pathSegments[1]}',
        {'t': uri.queryParameters['t']!},
      ).toString();
    }

    return null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
