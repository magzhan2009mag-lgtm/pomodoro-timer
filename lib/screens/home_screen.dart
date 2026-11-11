import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pomodoro_controller.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/mode_selector.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/timer_dial.dart';
import '../widgets/today_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription<PomodoroMode>? _completions;

  PomodoroController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completions = _c.completions.listen(_onCompleted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers may have been frozen in the background: catch up immediately.
    if (state == AppLifecycleState.resumed) _c.tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completions?.cancel();
    super.dispose();
  }

  void _onCompleted(PomodoroMode finished) {
    if (!mounted) return;
    final text = finished == PomodoroMode.focus
        ? 'Сессия завершена. Время перерыва.'
        : 'Перерыв окончен. Пора за работу.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
      ));
  }

  Future<void> _selectMode(PomodoroMode mode) async {
    if (_c.status != TimerStatus.idle) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text(
            'Прервать сессию?',
            style: display(18, color: AppColors.cocoa),
          ),
          content: Text(
            'Таймер переключится на «${modeLabel(mode)}», '
            'текущая сессия не будет засчитана.',
            style: body(15, color: AppColors.cocoa, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Продолжить сессию'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forMode(_c.mode),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Прервать'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _c.selectMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _c.toggle,
        const SingleActivator(LogicalKeyboardKey.keyR): _c.reset,
        const SingleActivator(LogicalKeyboardKey.keyN): _c.skip,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: AppColors.forMode(_c.mode)),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            builder: (context, bg, _) => _buildPage(context, bg!),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, Color bg) {
    final c = _c;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: bg,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: LayoutBuilder(
                builder: (context, box) {
                  final dial = min(box.maxWidth - 56, box.maxHeight * 0.46)
                      .clamp(200.0, 340.0);
                  return CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Column(
                            children: [
                              _Header(onSettings: () => showSettingsSheet(context, c)),
                              const SizedBox(height: 16),
                              ModeSelector(
                                mode: c.mode,
                                background: bg,
                                onSelected: _selectMode,
                              ),
                              const Spacer(),
                              const SizedBox(height: 24),
                              TimerDial(controller: c, size: dial),
                              const SizedBox(height: 28),
                              const Spacer(),
                              TimerControls(
                                isRunning: c.isRunning,
                                background: bg,
                                onToggle: c.toggle,
                                onReset: c.status == TimerStatus.idle ? null : c.reset,
                                onSkip: c.skip,
                              ),
                              const SizedBox(height: 32),
                              TodayPanel(
                                sessions: c.todaySessions,
                                focusMinutes: c.todayFocusMinutes,
                                plannedFocusMinutes: c.settings.focusMinutes,
                                background: bg,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Помидор', style: display(19, weight: 640)),
        const Spacer(),
        IconButton(
          tooltip: 'Настройки',
          onPressed: onSettings,
          color: AppColors.ink,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}
