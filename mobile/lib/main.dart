// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/lazy_bill_claim_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'package:checks_frontend/screens/tabs/tabs_screen.dart';
import 'screens/settings/services/preferences_service.dart';
import 'config/theme.dart';
import 'services/invite_link_service.dart';
import 'services/version_policy_service.dart';

// Purpose: Entry point for the Billington bill-splitting application.
// This file initializes the app and sets up the global theme and navigation routes.
//
// Features:
// - Configures app-wide theming with light/dark mode support
// - Sets up navigation routes to key screens
// - Initializes Flutter binding
// - Loads saved accent color preference on startup

/// App entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved accent color before running the app
  final prefsService = PreferencesService();
  final savedColor = await prefsService.getAccentColor();
  if (savedColor != null) {
    AppTheme.setPrimaryColor(Color(savedColor));
  }

  final updatePolicyFuture = VersionPolicyService().check();
  await InviteLinkService().initialize();

  runApp(MyApp(versionPolicyFuture: updatePolicyFuture));
  InviteLinkService.pendingShareLink.addListener(_routePendingShareLink);
  WidgetsBinding.instance.addPostFrameCallback((_) => _routePendingShareLink());
}

bool _isRoutingShareLink = false;
bool _appReadyForShareLinks = false;

void _markAppReadyForShareLinks() {
  _appReadyForShareLinks = true;
  WidgetsBinding.instance.addPostFrameCallback((_) => _routePendingShareLink());
}

Future<void> _routePendingShareLink() async {
  if (_isRoutingShareLink) return;
  if (!_appReadyForShareLinks) return;
  final link = InviteLinkService.pendingShareLink.value;
  final navigator = _rootNavigatorKey.currentState;
  if (link == null || navigator == null) return;
  final uri = Uri.tryParse(link);
  final segments = uri?.pathSegments ?? const <String>[];
  if (uri == null || segments.length < 2 || uri.queryParameters['t'] == null) {
    await InviteLinkService().clearPendingInvite(expectedLink: link);
    return;
  }

  _isRoutingShareLink = true;
  try {
    await InviteLinkService().clearPendingInvite(expectedLink: link);
    if (segments.first == 'b') {
      navigator.push(
        MaterialPageRoute(
          builder:
              (_) => LazyBillClaimScreen(
                billId: segments[1],
                token: uri.queryParameters['t']!,
              ),
        ),
      );
    } else if (segments.first == 't') {
      navigator.push(
        MaterialPageRoute(builder: (_) => TabsScreen(initialInviteUrl: link)),
      );
    }
  } finally {
    _isRoutingShareLink = false;
    if (InviteLinkService.pendingShareLink.value != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routePendingShareLink(),
      );
    }
  }
}

/// Root application widget that configures global app settings
class MyApp extends StatelessWidget {
  final Future<VersionPolicyDecision> versionPolicyFuture;

  const MyApp({super.key, required this.versionPolicyFuture});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, _, child) {
        return MaterialApp(
          navigatorKey: _rootNavigatorKey,
          title: 'Billington',
          // Theme configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system, // Follow system light/dark preference
          debugShowCheckedModeBanner: false,
          // Initial screen is always the splash screen
          home: SplashScreen(
            versionPolicyFuture: versionPolicyFuture,
            onStartupReady: _markAppReadyForShareLinks,
          ),

          // Named routes for navigation throughout the app
          routes: {
            '/landing':
                (context) =>
                    LandingScreen(onStartupReady: _markAppReadyForShareLinks),
            '/settings': (context) => const SettingsScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
          },
        );
      },
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
