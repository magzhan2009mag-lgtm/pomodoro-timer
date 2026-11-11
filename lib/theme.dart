import 'package:flutter/material.dart';

import 'pomodoro_controller.dart';

/// Palette: the whole screen takes the colour of the current mode,
/// everything on top of it is drawn in warm "ink".
abstract final class AppColors {
  static const tomato = Color(0xFFC63A2F); // focus
  static const leaf = Color(0xFF2E6A4F); // short break (tomato stem)
  static const dusk = Color(0xFF33416B); // long break (evening)
  static const ink = Color(0xFFFFF5EC); // text and marks on colour
  static const paper = Color(0xFFFFF5EC); // settings sheet surface
  static const cocoa = Color(0xFF2B1D1A); // text on paper

  static Color forMode(PomodoroMode mode) => switch (mode) {
        PomodoroMode.focus => tomato,
        PomodoroMode.shortBreak => leaf,
        PomodoroMode.longBreak => dusk,
      };
}

// Both fonts are variable; weight is set through the `wght` axis directly so
// the engine doesn't synthesise a fake bold on top of the default instance.

/// Unbounded: wide, rounded display face for the clock digits and headings.
TextStyle display(
  double size, {
  double weight = 600,
  Color color = AppColors.ink,
  double? height,
}) =>
    TextStyle(
      fontFamily: 'Unbounded',
      fontSize: size,
      color: color,
      height: height,
      fontVariations: [FontVariation('wght', weight)],
    );

/// Onest: interface text.
TextStyle body(
  double size, {
  double weight = 420,
  Color color = AppColors.ink,
  double? height,
}) =>
    TextStyle(
      fontFamily: 'Onest',
      fontSize: size,
      color: color,
      height: height,
      fontVariations: [FontVariation('wght', weight)],
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.tomato,
    surface: AppColors.paper,
    onSurface: AppColors.cocoa,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Onest',
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: body(15, color: AppColors.cocoa, weight: 500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

String modeLabel(PomodoroMode mode) => switch (mode) {
      PomodoroMode.focus => 'Фокус',
      PomodoroMode.shortBreak => 'Перерыв',
      PomodoroMode.longBreak => 'Длинный перерыв',
    };

/// Russian plural: plural(5, 'помидор', 'помидора', 'помидоров') → 'помидоров'.
String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}
