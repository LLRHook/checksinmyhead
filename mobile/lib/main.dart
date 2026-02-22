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
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings/services/preferences_service.dart';
import 'config/theme.dart';

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

  runApp(const MyApp());
}

/// Root application widget that configures global app settings
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Static callback for triggering theme rebuilds from anywhere in the app
  static VoidCallback? _restartCallback;

  /// Triggers a full app rebuild (e.g., after changing the accent color)
  static void restartApp() {
    _restartCallback?.call();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    MyApp._restartCallback = _restartApp;
  }

  @override
  void dispose() {
    MyApp._restartCallback = null;
    super.dispose();
  }

  void _restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: MaterialApp(
        title: 'Billington',
        // Theme configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // Follow system light/dark preference
        debugShowCheckedModeBanner: false,
        // Initial screen is always the splash screen
        home: const SplashScreen(),

        // Named routes for navigation throughout the app
        routes: {
          '/landing': (context) => const LandingScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
        },
      ),
    );
  }
}
