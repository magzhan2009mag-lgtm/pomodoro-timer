import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PomodoroMode { focus, shortBreak, longBreak }

enum TimerStatus { idle, running, paused }

class PomodoroSettings {
  const PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakInterval = 4,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
    this.soundEnabled = true,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval;
  final bool autoStartBreaks;
  final bool autoStartFocus;
  final bool soundEnabled;

  Duration durationFor(PomodoroMode mode) => Duration(
        minutes: switch (mode) {
          PomodoroMode.focus => focusMinutes,
          PomodoroMode.shortBreak => shortBreakMinutes,
          PomodoroMode.longBreak => longBreakMinutes,
        },
      );

  PomodoroSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakInterval,
    bool? autoStartBreaks,
    bool? autoStartFocus,
    bool? soundEnabled,
  }) =>
      PomodoroSettings(
        focusMinutes: focusMinutes ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        longBreakInterval: longBreakInterval ?? this.longBreakInterval,
        autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
        autoStartFocus: autoStartFocus ?? this.autoStartFocus,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  Map<String, Object> toJson() => {
        'focus': focusMinutes,
        'short': shortBreakMinutes,
        'long': longBreakMinutes,
        'interval': longBreakInterval,
        'autoBreaks': autoStartBreaks,
        'autoFocus': autoStartFocus,
        'sound': soundEnabled,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> j) => PomodoroSettings(
        focusMinutes: j['focus'] as int? ?? 25,
        shortBreakMinutes: j['short'] as int? ?? 5,
        longBreakMinutes: j['long'] as int? ?? 15,
        longBreakInterval: j['interval'] as int? ?? 4,
        autoStartBreaks: j['autoBreaks'] as bool? ?? false,
        autoStartFocus: j['autoFocus'] as bool? ?? false,
        soundEnabled: j['sound'] as bool? ?? true,
      );
}

/// Plays the "time's up" sound. Abstracted so tests don't touch plugins.
abstract class Chime {
  Future<void> play();
}

class AssetChime implements Chime {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/chime.wav'));
    } catch (e) {
      debugPrint('Chime failed: $e');
    }
  }
}

/// Timer state + persistence. Time is tracked by an absolute end timestamp,
/// so it stays accurate when the app is backgrounded or even closed.
class PomodoroController extends ChangeNotifier {
  PomodoroController({
    required SharedPreferences prefs,
    required Chime chime,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _chime = chime,
        _now = clock ?? DateTime.now {
    _restore();
  }

  static const _kSettings = 'settings';
  static const _kStats = 'stats'; // {"2026-11-11": {"s": 3, "m": 75}}
  static const _kTimer = 'timer';

  final SharedPreferences _prefs;
  final Chime _chime;
  final DateTime Function() _now;
  final _completions = StreamController<PomodoroMode>.broadcast();

  PomodoroSettings _settings = const PomodoroSettings();
  PomodoroMode _mode = PomodoroMode.focus;
  TimerStatus _status = TimerStatus.idle;
  DateTime? _endTime;
  Duration _pausedRemaining = Duration.zero;
  Duration _total = Duration.zero;
  int _completedInCycle = 0;
  Map<String, Map<String, int>> _stats = {};
  Timer? _ticker;
  int _lastShownSecond = -1;

  /// Emits the mode that just finished naturally (not skipped).
  Stream<PomodoroMode> get completions => _completions.stream;

  PomodoroSettings get settings => _settings;
  PomodoroMode get mode => _mode;
  TimerStatus get status => _status;
  bool get isRunning => _status == TimerStatus.running;
  Duration get total => _total;
  int get completedInCycle => _completedInCycle;

  Duration get remaining {
    if (_status != TimerStatus.running) return _pausedRemaining;
    final left = _endTime!.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction of time remaining: 1.0 at start, 0.0 when done.
  double get progress => _total.inMilliseconds == 0
      ? 0
      : (remaining.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

  int get todaySessions => _stats[_dayKey(_now())]?['s'] ?? 0;
  int get todayFocusMinutes => _stats[_dayKey(_now())]?['m'] ?? 0;

  // ---- actions ------------------------------------------------------------

  void start() {
    if (isRunning) return;
    if (_pausedRemaining <= Duration.zero) _pausedRemaining = _total;
    _endTime = _now().add(_pausedRemaining);
    _status = TimerStatus.running;
    _startTicker();
    _changed();
  }

  void pause() {
    if (!isRunning) return;
    _pausedRemaining = remaining;
    _status = TimerStatus.paused;
    _endTime = null;
    _ticker?.cancel();
    _changed();
  }

  void toggle() => isRunning ? pause() : start();

  void reset() => _enter(_mode, autoStart: false);

  /// Jump to the next mode without counting the current session.
  void skip() {
    if (_mode == PomodoroMode.longBreak) _completedInCycle = 0;
    _enter(_nextMode(), autoStart: false);
  }

  void selectMode(PomodoroMode mode) => _enter(mode, autoStart: false);

  void updateSettings(PomodoroSettings s) {
    _settings = s;
    _prefs.setString(_kSettings, jsonEncode(s.toJson()));
    // A session in progress keeps its length; an idle one picks up the change.
    if (_status == TimerStatus.idle) {
      _total = s.durationFor(_mode);
      _pausedRemaining = _total;
    }
    _changed();
  }

  void resetToday() {
    _stats.remove(_dayKey(_now()));
    _saveStats();
    _changed();
  }

  void previewChime() => _chime.play();

  /// Called periodically while running, and when the app comes back to the
  /// foreground (mobile OSes suspend Dart timers in the background).
  void tick() {
    if (!isRunning) return;
    final left = remaining;
    if (left == Duration.zero) {
      _complete(playSound: true);
      return;
    }
    final second = (left.inMilliseconds / 1000).ceil();
    if (second != _lastShownSecond) {
      _lastShownSecond = second;
      notifyListeners();
    }
  }

  // ---- internals ----------------------------------------------------------

  void _complete({required bool playSound, bool allowAutoStart = true}) {
    final finished = _mode;
    if (finished == PomodoroMode.focus) {
      _completedInCycle++;
      final day = _stats.putIfAbsent(_dayKey(_now()), () => {'s': 0, 'm': 0});
      day['s'] = (day['s'] ?? 0) + 1;
      day['m'] = (day['m'] ?? 0) + _total.inMinutes;
      _saveStats();
    }
    final next = _nextMode();
    if (finished == PomodoroMode.longBreak) _completedInCycle = 0;

    final auto = allowAutoStart &&
        (next == PomodoroMode.focus
            ? _settings.autoStartFocus
            : _settings.autoStartBreaks);
    _enter(next, autoStart: auto);

    if (playSound && _settings.soundEnabled) _chime.play();
    _completions.add(finished);
  }

  PomodoroMode _nextMode() {
    if (_mode != PomodoroMode.focus) return PomodoroMode.focus;
    // _completedInCycle already includes the session that just ended.
    return _completedInCycle >= _settings.longBreakInterval
        ? PomodoroMode.longBreak
        : PomodoroMode.shortBreak;
  }

  void _enter(PomodoroMode mode, {required bool autoStart}) {
    _ticker?.cancel();
    _mode = mode;
    _total = _settings.durationFor(mode);
    _pausedRemaining = _total;
    _endTime = null;
    _status = TimerStatus.idle;
    if (autoStart) {
      start(); // calls _changed()
    } else {
      _changed();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => tick());
  }

  void _changed() {
    _lastShownSecond = -1;
    _saveTimer();
    notifyListeners();
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _saveStats() {
    // Keep ~2 months of history.
    final cutoff = _dayKey(_now().subtract(const Duration(days: 60)));
    _stats.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    _prefs.setString(_kStats, jsonEncode(_stats));
  }

  void _saveTimer() {
    _prefs.setString(
      _kTimer,
      jsonEncode({
        'mode': _mode.name,
        'status': _status.name,
        'end': _endTime?.millisecondsSinceEpoch,
        'left': _pausedRemaining.inMilliseconds,
        'total': _total.inMilliseconds,
        'cycle': _completedInCycle,
      }),
    );
  }

  void _restore() {
    // Each piece is read independently so one corrupted entry can't take the
    // others down with it (and get overwritten with defaults on next save).
    try {
      final s = _prefs.getString(_kSettings);
      if (s != null) _settings = PomodoroSettings.fromJson(jsonDecode(s));
    } catch (e) {
      debugPrint('Failed to read settings: $e');
    }
    try {
      final st = _prefs.getString(_kStats);
      if (st != null) {
        _stats = (jsonDecode(st) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, Map<String, int>.from(v as Map)),
        );
      }
    } catch (e) {
      debugPrint('Failed to read stats: $e');
    }

    _total = _settings.durationFor(_mode);
    _pausedRemaining = _total;

    final t = _prefs.getString(_kTimer);
    if (t == null) return;
    try {
      final j = jsonDecode(t) as Map<String, dynamic>;
      _mode = PomodoroMode.values.byName(j['mode'] as String);
      _completedInCycle = j['cycle'] as int? ?? 0;
      _total = Duration(milliseconds: j['total'] as int);
      _pausedRemaining = Duration(milliseconds: j['left'] as int);
      final status = TimerStatus.values.byName(j['status'] as String);
      final end = j['end'] as int?;
      if (status == TimerStatus.running && end != null) {
        _endTime = DateTime.fromMillisecondsSinceEpoch(end);
        _status = TimerStatus.running;
        if (_endTime!.isAfter(_now())) {
          _startTicker();
        } else {
          // Finished while the app was closed: count it quietly.
          _complete(playSound: false, allowAutoStart: false);
        }
      } else {
        _status = status;
      }
    } catch (e) {
      debugPrint('Failed to restore timer: $e');
      _enter(PomodoroMode.focus, autoStart: false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _completions.close();
    super.dispose();
  }
}
