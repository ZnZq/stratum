import 'dart:async';

import 'tick_scheduler.dart';

/// A source of monotonic time.
///
/// The abstraction exists so a test can move time by hand. Production has one
/// implementation, [StopwatchClock].
abstract class MonotonicClock {
  Duration get elapsed;
}

/// Backed by `Stopwatch` rather than `DateTime.now()`.
///
/// Wall-clock time jumps: NTP corrects it, the player changes time zone, or the
/// player deliberately moves it forward to farm resources. Monotonic time never
/// jumps.
///
/// Wall-clock time is needed only by the offline calculation, since only it
/// survives a killed process, and that is where it belongs together with the
/// defences against a tampered clock.
class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}

/// Feeds a [TickScheduler] with real time.
///
/// Almost no logic lives here — it is all in the scheduler, which is tested
/// synchronously. This class owns the timer, the measurement and the callback.
class TickEngine {
  TickEngine({
    required this.scheduler,
    required this.onBatch,
    MonotonicClock? clock,
  }) : _clock = clock ?? StopwatchClock() {
    _lastSync = _clock.elapsed;
  }

  final TickScheduler scheduler;

  /// Empty batches are not delivered.
  final void Function(TickBatch batch) onBatch;

  final MonotonicClock _clock;

  Timer? _timer;
  late Duration _lastSync;
  bool _disposed = false;
  bool _syncing = false;

  bool get isRunning => _timer != null;

  TickRate get rate => scheduler.rate;

  /// Changes the rate and re-arms the timer for the new interval.
  ///
  /// Going straight to `scheduler.rate` would leave the timer period stale, so
  /// the new rate would only take effect an interval later.
  ///
  /// The time already served is banked first, so the scheduler can carry it
  /// across as a fraction of the new interval. Without that sync it would be
  /// lost twice over -- the accumulator holds only what the timer has settled,
  /// and the rest is the gap since the last sync.
  set rate(TickRate value) {
    if (isRunning) syncNow();
    scheduler.rate = value;
    _lastSync = _clock.elapsed;
    if (isRunning) {
      _stopTimer();
      _startTimer();
    }
  }

  void start() {
    _assertUsable();
    if (isRunning) return;
    _lastSync = _clock.elapsed;
    _startTimer();
  }

  /// Banks whatever time has already accrued, then stops the timer.
  ///
  /// Without the sync, pausing would throw away the part of an interval already
  /// served and the progress bar would snap back to empty on resume.
  void stop() {
    if (isRunning) syncNow();
    _stopTimer();
  }

  /// How far the current interval has been served, in `[0, 1]`.
  ///
  /// Computed from the clock at the moment of the call, not from the
  /// scheduler's accumulator: the accumulator only moves when the timer fires,
  /// so a bar driven by it would sit at zero for a whole interval and then
  /// jump. A UI reads this once per frame from its own `Ticker`.
  ///
  /// Clamped at full rather than wrapped: a late timer should show a bar
  /// waiting to fire, not one that restarted without a tick having happened.
  double get progress {
    _assertUsable();
    final interval = scheduler.rate.interval.inMicroseconds;
    return (_servedMicroseconds() / interval).clamp(0.0, 1.0);
  }

  /// How much of the current interval is left to serve.
  Duration get timeToNextTick {
    _assertUsable();
    final remaining =
        scheduler.rate.interval.inMicroseconds - _servedMicroseconds();
    return Duration(microseconds: remaining < 0 ? 0 : remaining);
  }

  /// Time already served toward the next fire.
  ///
  /// While stopped, only what the scheduler banked counts: a paused game must
  /// not keep filling, and the time spent paused is discarded on resume.
  int _servedMicroseconds() {
    final banked = scheduler.pending.inMicroseconds;
    if (!isRunning) return banked;
    return banked + (_clock.elapsed - _lastSync).inMicroseconds;
  }

  /// Settles accumulated time immediately instead of waiting for the timer.
  ///
  /// Needed where the app itself knows time has passed: returning from the
  /// background, resuming after a pause.
  void syncNow() {
    _assertUsable();

    // A callback that stops the engine re-enters here through stop(), and by
    // then real time has moved on, so the sync would deliver another batch and
    // recurse without end. Stopping from inside onBatch is the ordinary way to
    // pause a loop that has hit its cap, so the guard is not an edge case.
    if (_syncing) return;
    _syncing = true;
    try {
      final now = _clock.elapsed;
      final delta = now - _lastSync;
      _lastSync = now;

      if (delta <= Duration.zero) return;

      final batch = scheduler.advance(delta);
      if (!batch.isEmpty) onBatch(batch);
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _stopTimer();
    _disposed = true;
  }

  void _startTimer() {
    // A rate change leaves part of the interval already served, and a plain
    // periodic timer would fire a whole interval after it -- the bar would sit
    // full and wait. So the first fire is short by whatever was carried over,
    // and only then does the loop settle into its period.
    final remaining = timeToNextTick;
    if (remaining >= scheduler.rate.interval) {
      _timer = Timer.periodic(scheduler.rate.interval, (_) => syncNow());
      return;
    }
    _timer = Timer(remaining, () {
      syncNow();
      if (isRunning) {
        _timer = Timer.periodic(scheduler.rate.interval, (_) => syncNow());
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('TickEngine is already disposed');
    }
  }
}
