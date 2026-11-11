import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pomodoro_controller.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final controller = PomodoroController(prefs: prefs, chime: AssetChime());
  runApp(PomodoroApp(controller: controller));
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key, required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Помидор',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeScreen(controller: controller),
    );
  }
}
