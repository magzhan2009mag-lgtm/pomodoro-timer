import 'package:flutter/material.dart';

import '../pomodoro_controller.dart';
import '../theme.dart';

/// Three-way switch with an ink pill that slides under the selected mode.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.mode,
    required this.background,
    required this.onSelected,
  });

  final PomodoroMode mode;

  /// Current (animated) screen colour; used for the label on the pill.
  final Color background;
  final ValueChanged<PomodoroMode> onSelected;

  static const _short = {
    PomodoroMode.focus: 'Фокус',
    PomodoroMode.shortBreak: 'Перерыв',
    PomodoroMode.longBreak: 'Длинный',
  };

  @override
  Widget build(BuildContext context) {
    final index = PomodoroMode.values.indexOf(mode);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 380);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutBack,
            alignment: Alignment(-1 + index * 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final m in PomodoroMode.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: m == mode,
                    label: modeLabel(m),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: m == mode ? null : () => onSelected(m),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: body(
                            14.5,
                            weight: m == mode ? 600 : 460,
                            color: m == mode
                                ? background
                                : AppColors.ink.withValues(alpha: 0.85),
                          ),
                          child: Text(_short[m]!, maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
