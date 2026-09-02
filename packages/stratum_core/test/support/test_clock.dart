import 'package:fake_async/fake_async.dart';
import 'package:stratum_core/stratum_core.dart';

/// A hand-driven clock: what `Stopwatch` does, except time only moves when
/// the test says so.
class TestClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) => _elapsed += by;
}

/// Time as the app really experiences it: the clock and the timers move
/// together, in slices small enough that no timer ever fires against a
/// clock that has already run ahead of it.
void elapse(FakeAsync async, TestClock clock, Duration by) {
  const slice = Duration(milliseconds: 5);
  var left = by;
  while (left > Duration.zero) {
    final step = left < slice ? left : slice;
    clock.advance(step);
    async.elapse(step);
    left -= step;
  }
}

/// Moves the fake timer and the fake clock together in one step: the
/// engine learns about time from the clock but fires from the timer, so a
/// test must advance both.
void elapseBoth(FakeAsync async, TestClock clock, Duration by) {
  clock.advance(by);
  async.elapse(by);
}
