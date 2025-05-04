import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;

  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checkmate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      routes: {
        '/landing': (context) => const LandingScreen(),
        '/settings': (context) => SettingsScreen(isOnboarding: isFirstLaunch),
      },
    );
  }
}
