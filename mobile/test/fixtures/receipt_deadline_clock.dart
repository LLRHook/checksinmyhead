import 'dart:async';

/// Controlled deadline phase for real loopback ownership tests, not wall-time proof.
/// Other timers (wire observations, fixture cleanup) retain their real budgets.
class ReceiptDeadlineClock {
  final Duration deadline;
  Duration elapsed = Duration.zero;
  final timers = <Timer>[];

  ReceiptDeadlineClock(this.deadline);

  Future<T> run<T>(Future<T> Function() body) => runZoned<Future<T>>(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (duration != deadline) {
          return parent.createTimer(zone, duration, callback);
        }
        final timer = _PhaseTimer(() => zone.runGuarded(callback));
        timers.add(timer);
        return timer;
      },
    ),
  );

  void expire() {
    if (timers.length != 1 || !timers.single.isActive) {
      throw StateError('Expected one active owned deadline');
    }
    elapsed = deadline;
    (timers.single as _PhaseTimer).fire();
  }

  void close() {
    for (final timer in timers) {
      timer.cancel();
    }
  }
}

class _PhaseTimer implements Timer {
  final void Function() callback;
  bool _active = true;
  int _tick = 0;
  _PhaseTimer(this.callback);

  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) throw StateError('Deadline already canceled');
    _active = false;
    _tick = 1;
    callback();
  }
}
