import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Today's tally: count, focus minutes, and one small tomato per session.
class TodayPanel extends StatelessWidget {
  const TodayPanel({
    super.key,
    required this.sessions,
    required this.focusMinutes,
    required this.plannedFocusMinutes,
    required this.background,
  });

  final int sessions;
  final int focusMinutes;
  final int plannedFocusMinutes;
  final Color background;

  static const _maxShown = 16;

  @override
  Widget build(BuildContext context) {
    final dim = AppColors.ink.withValues(alpha: 0.72);
    final shown = min(sessions, _maxShown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сегодня', style: body(14, color: dim, weight: 500)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text(
                '$sessions',
                key: ValueKey(sessions),
                style: display(30, weight: 600, height: 1.1),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              plural(sessions, 'помидор', 'помидора', 'помидоров'),
              style: body(17, weight: 500),
            ),
            const Spacer(),
            Text(
              '$focusMinutes мин в фокусе',
              style: body(14, color: dim),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sessions == 0)
          Text(
            'Первый помидор появится здесь '
            'после $plannedFocusMinutes мин фокуса.',
            style: body(14, color: dim, height: 1.4),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < shown; i++)
                // Keyed so only newly earned tomatoes play the pop-in.
                TweenAnimationBuilder<double>(
                  key: ValueKey(i),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: _Tomato(calyx: background),
                ),
              if (sessions > shown)
                Text('+${sessions - shown}', style: body(14, weight: 600)),
            ],
          ),
      ],
    );
  }
}

/// A tiny tomato: ink body with a calyx cut out in the screen colour.
class _Tomato extends StatelessWidget {
  const _Tomato({required this.calyx});

  final Color calyx;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(18), painter: _TomatoPainter(calyx));
}

class _TomatoPainter extends CustomPainter {
  _TomatoPainter(this.calyx);

  final Color calyx;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w * 0.56);
    // Slightly squashed body, like a real tomato.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.96, height: w * 0.84),
      Paint()..color = AppColors.ink,
    );
    // Five-point calyx on top.
    final top = Offset(w / 2, w * 0.2);
    final leaf = Paint()..color = calyx;
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5;
      final b = a + pi / 5;
      final outer = top + Offset(cos(a), sin(a) * 0.6) * w * 0.26;
      final inner = top + Offset(cos(b), sin(b) * 0.6) * w * 0.08;
      i == 0 ? path.moveTo(outer.dx, outer.dy) : path.lineTo(outer.dx, outer.dy);
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, leaf);
  }

  @override
  bool shouldRepaint(_TomatoPainter old) => old.calyx != calyx;
}
