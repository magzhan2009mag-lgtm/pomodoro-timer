import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_1/main.dart';
import 'package:project_1/pomodoro_controller.dart';
import 'package:project_1/widgets/today_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentChime implements Chime {
  @override
  Future<void> play() async {}
}

void main() {
  testWidgets('shows the dial and toggles play/pause', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = PomodoroController(prefs: prefs, chime: _SilentChime());

    await tester.pumpWidget(PomodoroApp(controller: c));
    await tester.pump();

    expect(find.bySemanticsLabel('Осталось 25:00'), findsOneWidget);
    expect(find.text('Фокус'), findsOneWidget);
    expect(find.text('Сессия 1 из 4'), findsOneWidget);
    final today = find.byType(TodayPanel);
    expect(find.descendant(of: today, matching: find.text('0')), findsOneWidget);
    expect(find.descendant(of: today, matching: find.text('помидоров')),
        findsOneWidget);

    await tester.tap(find.byTooltip('Старт (пробел)'));
    await tester.pump();
    expect(c.isRunning, isTrue);
    expect(find.byTooltip('Пауза (пробел)'), findsOneWidget);

    // Switching mode mid-session asks first.
    // (pumpAndSettle would never settle: the dial animates every frame.)
    await tester.tap(find.text('Перерыв'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Прервать сессию?'), findsOneWidget);
    await tester.tap(find.text('Прервать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.mode, PomodoroMode.shortBreak);
    expect(c.isRunning, isFalse);

    // Unmount so no tickers or timers outlive the test.
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
