import 'package:flutter/material.dart';

import '../pomodoro_controller.dart';
import '../theme.dart';

Future<void> showSettingsSheet(BuildContext context, PomodoroController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.paper,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => _SettingsSheet(controller: c),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final s = c.settings;
        final accent = AppColors.forMode(c.mode);
        void set(PomodoroSettings next) => c.updateSettings(next);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Настройки', style: display(20, color: AppColors.cocoa)),
                if (c.status != TimerStatus.idle) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Новая длительность начнёт действовать со следующей сессии.',
                    style: body(13.5, color: AppColors.cocoa.withValues(alpha: 0.65)),
                  ),
                ],
                const SizedBox(height: 16),
                _MinutesSlider(
                  label: 'Фокус',
                  value: s.focusMinutes,
                  min: 1,
                  max: 60,
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(focusMinutes: v)),
                ),
                _MinutesSlider(
                  label: 'Короткий перерыв',
                  value: s.shortBreakMinutes,
                  min: 1,
                  max: 15,
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(shortBreakMinutes: v)),
                ),
                _MinutesSlider(
                  label: 'Длинный перерыв',
                  value: s.longBreakMinutes,
                  min: 5,
                  max: 40,
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(longBreakMinutes: v)),
                ),
                _MinutesSlider(
                  label: 'Длинный перерыв после',
                  value: s.longBreakInterval,
                  min: 2,
                  max: 8,
                  unit: (v) => plural(v, 'сессии', 'сессий', 'сессий'),
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(longBreakInterval: v)),
                ),
                const SizedBox(height: 8),
                _Toggle(
                  label: 'Сразу начинать перерыв',
                  value: s.autoStartBreaks,
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(autoStartBreaks: v)),
                ),
                _Toggle(
                  label: 'Сразу начинать фокус после перерыва',
                  value: s.autoStartFocus,
                  accent: accent,
                  onChanged: (v) => set(s.copyWith(autoStartFocus: v)),
                ),
                _Toggle(
                  label: 'Звук в конце сессии',
                  value: s.soundEnabled,
                  accent: accent,
                  onChanged: (v) {
                    set(s.copyWith(soundEnabled: v));
                    if (v) c.previewChime();
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.cocoa,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  ),
                  onPressed: c.todaySessions == 0
                      ? null
                      : () => _confirmReset(context, c),
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  label: Text('Обнулить статистику за сегодня', style: body(15, color: AppColors.cocoa)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, PomodoroController c) async {
    final n = c.todaySessions;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Обнулить статистику?', style: display(18, color: AppColors.cocoa)),
        content: Text(
          'Сегодняшние $n ${plural(n, 'помидор', 'помидора', 'помидоров')} '
          'и ${c.todayFocusMinutes} мин фокуса будут удалены.',
          style: body(15, color: AppColors.cocoa, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.tomato),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Обнулить'),
          ),
        ],
      ),
    );
    if (ok == true) c.resetToday();
  }
}

class _MinutesSlider extends StatelessWidget {
  const _MinutesSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.onChanged,
    this.unit,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final Color accent;
  final ValueChanged<int> onChanged;
  final String Function(int)? unit;

  @override
  Widget build(BuildContext context) {
    final suffix = unit?.call(value) ?? 'мин';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: body(15.5, color: AppColors.cocoa))),
              Text(
                '$value $suffix',
                style: body(15.5, weight: 600, color: AppColors.cocoa),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              thumbColor: accent,
              inactiveTrackColor: accent.withValues(alpha: 0.18),
              overlayColor: accent.withValues(alpha: 0.12),
              trackHeight: 4,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              semanticFormatterCallback: (v) => '${v.round()} $suffix',
              onChanged: (v) {
                final next = v.round();
                if (next != value) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: body(15.5, color: AppColors.cocoa)),
      value: value,
      activeThumbColor: AppColors.paper,
      activeTrackColor: accent,
      onChanged: onChanged,
    );
  }
}
