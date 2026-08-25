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

  bool get isRunning => _timer != null;

  TickRate get rate => scheduler.rate;

  /// Changes the rate and re-arms the timer for the new interval.
  ///
  /// Going straight to `scheduler.rate` would leave the timer period stale, so
  /// the new rate would only take effect an interval later.
  set rate(TickRate value) {
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

  void stop() => _stopTimer();

  /// Settles accumulated time immediately instead of waiting for the timer.
  ///
  /// Needed where the app itself knows time has passed: returning from the
  /// background, resuming after a pause.
  void syncNow() {
    _assertUsable();

    final now = _clock.elapsed;
    final delta = now - _lastSync;
    _lastSync = now;

    if (delta <= Duration.zero) return;

    final batch = scheduler.advance(delta);
    if (!batch.isEmpty) onBatch(batch);
  }

  void dispose() {
    _stopTimer();
    _disposed = true;
  }

  void _startTimer() {
    _timer = Timer.periodic(scheduler.rate.interval, (_) => syncNow());
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
