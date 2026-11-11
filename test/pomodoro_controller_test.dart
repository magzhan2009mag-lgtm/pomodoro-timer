import 'package:flutter_test/flutter_test.dart';
import 'package:project_1/pomodoro_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeChime implements Chime {
  int plays = 0;
  @override
  Future<void> play() async => plays++;
}

/// Manually advanced clock.
class FakeClock {
  DateTime now = DateTime(2026, 11, 11, 9, 0);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeClock clock;
  late FakeChime chime;

  PomodoroController make() {
    final c = PomodoroController(prefs: prefs, chime: chime, clock: clock.call);
    addTearDown(c.dispose);
    return c;
  }

  /// Runs the current session to its end and lets the controller notice.
  void finish(PomodoroController c) {
    if (!c.isRunning) c.start();
    clock.advance(c.remaining);
    c.tick();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = FakeClock();
    chime = FakeChime();
  });

  test('starts idle on a full 25-minute focus session', () {
    final c = make();
    expect(c.mode, PomodoroMode.focus);
    expect(c.status, TimerStatus.idle);
    expect(c.remaining, const Duration(minutes: 25));
    expect(c.progress, 1.0);
    expect(c.todaySessions, 0);
  });

  test('counts down from wall-clock time and freezes while paused', () {
    final c = make()..start();
    clock.advance(const Duration(minutes: 10));
    expect(c.remaining, const Duration(minutes: 15));
    expect(c.progress, closeTo(0.6, 1e-9));

    c.pause();
    clock.advance(const Duration(hours: 1));
    expect(c.remaining, const Duration(minutes: 15));

    c.start();
    clock.advance(const Duration(minutes: 5));
    expect(c.remaining, const Duration(minutes: 10));
  });

  test('finishing focus counts a session, plays the chime, goes to break',
      () async {
    final c = make();
    final finished = <PomodoroMode>[];
    c.completions.listen(finished.add);

    finish(c);
    await Future<void>.delayed(Duration.zero); // deliver stream event

    expect(c.todaySessions, 1);
    expect(c.todayFocusMinutes, 25);
    expect(chime.plays, 1);
    expect(finished, [PomodoroMode.focus]);
    expect(c.mode, PomodoroMode.shortBreak);
    expect(c.status, TimerStatus.idle);
    expect(c.remaining, const Duration(minutes: 5));
  });

  test('every 4th focus session leads to a long break, then the cycle resets',
      () {
    final c = make();
    for (var i = 0; i < 3; i++) {
      finish(c); // focus
      expect(c.mode, PomodoroMode.shortBreak);
      finish(c); // break
      expect(c.mode, PomodoroMode.focus);
    }
    finish(c); // 4th focus
    expect(c.mode, PomodoroMode.longBreak);
    expect(c.completedInCycle, 4);

    finish(c); // long break
    expect(c.mode, PomodoroMode.focus);
    expect(c.completedInCycle, 0);
    expect(c.todaySessions, 4);
  });

  test('skip moves on without counting the session', () {
    final c = make()..start();
    clock.advance(const Duration(minutes: 20));
    c.skip();
    expect(c.mode, PomodoroMode.shortBreak);
    expect(c.todaySessions, 0);
    expect(chime.plays, 0);
  });

  test('auto-start settings start the next session immediately', () {
    final c = make()
      ..updateSettings(const PomodoroSettings(autoStartBreaks: true));
    finish(c);
    expect(c.mode, PomodoroMode.shortBreak);
    expect(c.isRunning, isTrue);
  });

  test('no chime when sound is off', () {
    final c = make()
      ..updateSettings(const PomodoroSettings(soundEnabled: false));
    finish(c);
    expect(chime.plays, 0);
    expect(c.todaySessions, 1);
  });

  test('changing settings resizes an idle timer but not a running one', () {
    final c = make()..updateSettings(const PomodoroSettings(focusMinutes: 50));
    expect(c.remaining, const Duration(minutes: 50));

    c.start();
    clock.advance(const Duration(minutes: 1));
    c.updateSettings(const PomodoroSettings(focusMinutes: 10));
    expect(c.remaining, const Duration(minutes: 49));
    expect(c.total, const Duration(minutes: 50));
  });

  test('stats are kept per day', () {
    final c = make();
    finish(c);
    expect(c.todaySessions, 1);

    clock.advance(const Duration(days: 1));
    expect(c.todaySessions, 0, reason: 'a new day starts from zero');
    c
      ..selectMode(PomodoroMode.focus)
      ..start();
    finish(c);
    expect(c.todaySessions, 1);

    clock.advance(const Duration(days: -1));
    expect(c.todaySessions, 1, reason: 'yesterday is still stored');
  });

  test('resetToday clears only today', () {
    final c = make();
    finish(c);
    c.resetToday();
    expect(c.todaySessions, 0);
    expect(c.todayFocusMinutes, 0);
  });

  group('persistence', () {
    test('settings and stats survive a restart', () {
      make()
        ..updateSettings(const PomodoroSettings(focusMinutes: 40))
        ..start();
      clock.advance(const Duration(minutes: 40));
      // (no tick: app "closed" before noticing)

      final restored = make();
      expect(restored.settings.focusMinutes, 40);
      expect(restored.todaySessions, 1);
      expect(restored.todayFocusMinutes, 40);
    });

    test('a running timer resumes with the right remaining time', () {
      make().start();
      clock.advance(const Duration(minutes: 7));

      final restored = make();
      expect(restored.isRunning, isTrue);
      expect(restored.remaining, const Duration(minutes: 18));
    });

    test('a paused timer is restored paused', () {
      final c = make()..start();
      clock.advance(const Duration(minutes: 3));
      c.pause();

      final restored = make();
      expect(restored.status, TimerStatus.paused);
      expect(restored.remaining, const Duration(minutes: 22));
    });

    test('a session that ended while closed is counted quietly', () {
      make().start();
      clock.advance(const Duration(hours: 2));

      final restored = make();
      expect(restored.todaySessions, 1);
      expect(restored.mode, PomodoroMode.shortBreak);
      expect(restored.status, TimerStatus.idle);
      expect(chime.plays, 0);
    });

    test('corrupted settings do not wipe the stats', () async {
      SharedPreferences.setMockInitialValues({
        'settings': '{not json',
        'stats': '{"2026-11-11":{"s":3,"m":75}}',
      });
      prefs = await SharedPreferences.getInstance();
      final c = make();
      expect(c.settings.focusMinutes, 25);
      expect(c.todaySessions, 3);
      expect(c.todayFocusMinutes, 75);
    });

    test('corrupted saved data falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        'settings': '{not json',
        'timer': '{"mode":"nope"}',
      });
      prefs = await SharedPreferences.getInstance();
      final c = make();
      expect(c.settings.focusMinutes, 25);
      expect(c.mode, PomodoroMode.focus);
      expect(c.remaining, const Duration(minutes: 25));
    });
  });
}
