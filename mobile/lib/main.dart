// Spliq: Privacy-first receipt spliting
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
import 'config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Purpose: Entry point for the Spliq bill-splitting application.
// This file initializes the app, manages first-launch detection, and sets up
// the global theme and navigation routes.
//
// Features:
// - Detects if this is the first app launch for onboarding flow
// - Configures app-wide theming with light/dark mode support
// - Sets up navigation routes to key screens
// - Initializes Flutter binding and preferences

/// App entry point - initializes first launch detection before creating the app
void main() async {
  // Ensure Flutter bindings are initialized before accessing platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Load shared preferences to determine if this is the first app launch
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

  // Launch the app with first launch state
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

/// Root application widget that configures global app settings
class MyApp extends StatelessWidget {
  // Tracks whether this is the first time the app has been launched
  final bool isFirstLaunch;

  // Constructor requiring first launch status
  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spliq',
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
        '/settings': (context) => SettingsScreen(isOnboarding: isFirstLaunch),
      },
    );
  }
}
