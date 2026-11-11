import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../pomodoro_controller.dart';
import '../theme.dart';

/// Kitchen-timer dial: 60 ticks around the edge, a thick arc that winds back
/// to 12 o'clock as time runs out, and the remaining time in the middle.
class TimerDial extends StatefulWidget {
  const TimerDial({super.key, required this.controller, required this.size});

  final PomodoroController controller;
  final double size;

  @override
  State<TimerDial> createState() => _TimerDialState();
}

class _TimerDialState extends State<TimerDial> with TickerProviderStateMixin {
  /// What the painter draws; follows controller.progress every frame while
  /// running, and eases to a new value when the session is reset or switched.
  final _display = ValueNotifier<double>(1);
  late final Ticker _frames;
  late final AnimationController _refill;
  late final AnimationController _burst;
  Animation<double>? _refillTween;
  StreamSubscription<PomodoroMode>? _completions;
  bool _reduceMotion = false;

  PomodoroController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _display.value = _c.progress;
    _frames = createTicker((_) {
      if (!_refill.isAnimating) _display.value = _c.progress;
    });
    _refill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() => _display.value = _refillTween!.value);
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _c.addListener(_sync);
    _completions = _c.completions.listen((_) {
      if (!_reduceMotion) _burst.forward(from: 0);
    });
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  void _sync() {
    final target = _c.progress;
    if ((target - _display.value).abs() > 0.02 && !_reduceMotion) {
      _refillTween = Tween(begin: _display.value, end: target).animate(
        CurvedAnimation(parent: _refill, curve: Curves.easeInOutCubic),
      );
      _refill.forward(from: 0);
    } else if (!_refill.isAnimating) {
      _display.value = target;
    }

    if (_c.isRunning && !_frames.isActive) {
      _frames.start();
    } else if (!_c.isRunning && _frames.isActive) {
      _frames.stop();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_sync);
    _completions?.cancel();
    _frames.dispose();
    _refill.dispose();
    _burst.dispose();
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, child) => Transform.scale(
        // One soft "breath" outward when a session ends.
        scale: 1 + 0.045 * sin(pi * _burst.value),
        child: child,
      ),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DialPainter(progress: _display, burst: _burst),
          child: Center(
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) => _DialCenter(controller: _c, size: size),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialCenter extends StatelessWidget {
  const _DialCenter({required this.controller, required this.size});

  final PomodoroController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final interval = c.settings.longBreakInterval;
    final next = min(c.completedInCycle + 1, interval);
    final status = c.status == TimerStatus.paused
        ? 'Пауза'
        : switch (c.mode) {
            PomodoroMode.focus => 'Сессия $next из $interval',
            PomodoroMode.shortBreak => 'Дальше сессия $next из $interval',
            PomodoroMode.longBreak => 'Дальше новый цикл',
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RollingTime(remaining: c.remaining, fontSize: size * 0.17),
        SizedBox(height: size * 0.035),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            status,
            key: ValueKey(status),
            style: body(
              (size * 0.05).clamp(13.0, 16.0),
              color: AppColors.ink.withValues(alpha: 0.78),
            ),
          ),
        ),
        SizedBox(height: size * 0.035),
        _CycleDots(
          total: interval,
          done: min(c.completedInCycle, interval),
          current: c.mode == PomodoroMode.focus ? c.completedInCycle : null,
        ),
      ],
    );
  }
}

/// Dots for the sessions in the current cycle: filled = done,
/// ring = the session in progress, faint = still ahead.
class _CycleDots extends StatelessWidget {
  const _CycleDots({required this.total, required this.done, this.current});

  final int total;
  final int done;
  final int? current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? AppColors.ink
                  : AppColors.ink.withValues(alpha: i == current ? 0 : 0.22),
              border: i == current
                  ? Border.all(color: AppColors.ink, width: 1.5)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// MM:SS where each digit sits in a fixed-width cell and rolls down
/// (odometer-style) when it changes, so the clock never jitters sideways.
class RollingTime extends StatelessWidget {
  const RollingTime({
    super.key,
    required this.remaining,
    required this.fontSize,
  });

  final Duration remaining;
  final double fontSize;

  static final Map<double, double> _cellWidthCache = {};

  double _cellWidth(TextStyle style) => _cellWidthCache.putIfAbsent(fontSize, () {
        var widest = 0.0;
        for (var d = 0; d < 10; d++) {
          final tp = TextPainter(
            text: TextSpan(text: '$d', style: style),
            textDirection: TextDirection.ltr,
          )..layout();
          widest = max(widest, tp.width);
        }
        return widest;
      });

  @override
  Widget build(BuildContext context) {
    final secs = (remaining.inMilliseconds / 1000).ceil();
    final text = '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
    final style = display(fontSize, weight: 560, height: 1.15);
    final cell = _cellWidth(style);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Осталось $text',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < text.length; i++)
            if (text[i] == ':')
              Padding(
                padding: EdgeInsets.only(bottom: fontSize * 0.1),
                child: Text(':', style: style),
              )
            else
              _Digit(
                key: ValueKey(i),
                char: text[i],
                width: cell,
                style: style,
                animate: animate,
              ),
        ],
      ),
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit({
    super.key,
    required this.char,
    required this.width,
    required this.style,
    required this.animate,
  });

  final String char;
  final double width;
  final TextStyle style;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(char);
    return ClipRect(
      child: SizedBox(
        width: width,
        height: style.fontSize! * style.height!,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: animate ? 320 : 0),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            // New digit drops in from above, the old one falls out below.
            final incoming = child.key == current;
            final offset = Tween(
              begin: Offset(0, incoming ? -0.6 : 0.6),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offset,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(char, key: current, style: style),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress, required this.burst})
      : super(repaint: Listenable.merge([progress, burst]));

  final ValueListenable<double> progress;
  final Animation<double> burst;

  static const _ink = AppColors.ink;
  static const _ticks = 60;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = progress.value;

    // Scale ticks: lit for the time that's left, faint for time spent.
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < _ticks; i++) {
      final f = i / _ticks;
      final major = i % 5 == 0;
      final a = -pi / 2 + 2 * pi * f;
      final dir = Offset(cos(a), sin(a));
      final outer = r - r * 0.02;
      final inner = outer - (major ? r * 0.085 : r * 0.045);
      final lit = f < p;
      tick
        ..strokeWidth = major ? r * 0.018 : r * 0.011
        ..color = _ink.withValues(
          alpha: lit ? (major ? 0.95 : 0.6) : 0.16,
        );
      canvas.drawLine(c + dir * inner, c + dir * outer, tick);
    }

    final arcR = r * 0.77;
    final stroke = r * 0.07;

    // Track.
    canvas.drawCircle(
      c,
      arcR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _ink.withValues(alpha: 0.14),
    );

    // Remaining time, clockwise from 12 o'clock.
    if (p > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        -pi / 2,
        2 * pi * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
    }

    // Pointer knob at the end of the arc.
    final ka = -pi / 2 + 2 * pi * p;
    canvas.drawCircle(
      c + Offset(cos(ka), sin(ka)) * arcR,
      stroke * 0.9,
      Paint()..color = _ink,
    );

    // Completion ripple.
    final t = burst.value;
    if (t > 0 && t < 1) {
      final e = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        c,
        arcR + r * 0.32 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * (1 - e)
          ..color = _ink.withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.burst != burst;
}
