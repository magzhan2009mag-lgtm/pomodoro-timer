import 'package:flutter/material.dart';

import '../theme.dart';

/// Reset · Play/Pause · Skip.
class TimerControls extends StatelessWidget {
  const TimerControls({
    super.key,
    required this.isRunning,
    required this.background,
    required this.onToggle,
    required this.onReset,
    required this.onSkip,
  });

  final bool isRunning;
  final Color background;
  final VoidCallback onToggle;

  /// Null when there's nothing to reset (timer untouched).
  final VoidCallback? onReset;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SideButton(
          icon: Icons.replay_rounded,
          tooltip: 'Сбросить (R)',
          onPressed: onReset,
        ),
        const SizedBox(width: 28),
        _PlayButton(
          isRunning: isRunning,
          iconColor: background,
          onPressed: onToggle,
        ),
        const SizedBox(width: 28),
        _SideButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Пропустить (N)',
          onPressed: onSkip,
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.35,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 26,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.ink,
          fixedSize: const Size(56, 56),
          side: BorderSide(color: AppColors.ink.withValues(alpha: 0.35)),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

/// Big ink button whose icon morphs between play and pause.
class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.isRunning,
    required this.iconColor,
    required this.onPressed,
  });

  final bool isRunning;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.isRunning ? 1 : 0,
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(_PlayButton old) {
    super.didUpdateWidget(old);
    if (old.isRunning != widget.isRunning) {
      widget.isRunning ? _morph.forward() : _morph.reverse();
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isRunning ? 'Пауза (пробел)' : 'Старт (пробел)';
    return Tooltip(
      message: label,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: AppColors.ink,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: SizedBox.square(
              dimension: 84,
              child: Center(
                child: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _morph,
                  size: 38,
                  color: widget.iconColor,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
