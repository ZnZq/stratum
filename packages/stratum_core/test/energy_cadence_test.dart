import 'package:fake_async/fake_async.dart';
import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

class TestClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) => _elapsed += by;
}

/// Time as the app really experiences it: the clock and the timers move
/// together, in slices small enough that no timer ever fires against a clock
/// that has already run ahead of it.
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

void main() {
  group('a gauge that stops at its cap and is woken again', () {
    test('works off the remainder instead of freezing the bar full', () {
      fakeAsync((async) {
        final clock = TestClock();
        var full = false;
        var ticks = 0;
        late final TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 2))),
          onBatch: (batch) {
            ticks += batch.ticks;
            // Exactly what the energy loop does: fill, and sleep once the
            // gauge has nowhere left to put a point.
            if (full) engine.stop();
          },
          clock: clock,
        )..start();

        elapse(async, clock, const Duration(seconds: 5));
        full = true;
        elapse(async, clock, const Duration(seconds: 2));
        expect(engine.isRunning, isFalse);

        // Spending wakes it, and the rate moves at the same moment, because
        // buying the supply part is what spent the resource. Both of those
        // sync the engine mid-interval, which is where a remainder is born.
        full = false;
        engine.rate = TickRate(const Duration(milliseconds: 1789));
        engine.start();

        // One interval is all it may take to work that remainder off.
        elapse(async, clock, const Duration(milliseconds: 1789));
        final before = ticks;
        elapse(async, clock, const Duration(milliseconds: 60));

        expect(
          engine.progress,
          lessThan(0.25),
          reason:
              'just after a tick the interval is barely served, so the bar '
              'starts over rather than standing near full',
        );
        expect(
          ticks,
          greaterThan(before - 1),
          reason: 'and the loop is still delivering',
        );

        engine.dispose();
      });
    });

    test('the bar sweeps the whole way between two ticks', () {
      fakeAsync((async) {
        final clock = TestClock();
        late final TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(
            rate: TickRate(const Duration(milliseconds: 1000)),
          ),
          onBatch: (_) {},
          clock: clock,
        )..start();

        elapse(async, clock, const Duration(milliseconds: 3000));
        final readings = <double>[];
        for (var i = 0; i < 10; i++) {
          elapse(async, clock, const Duration(milliseconds: 100));
          readings.add(engine.progress);
        }

        expect(
          readings.reduce((a, b) => a < b ? a : b),
          lessThan(0.25),
          reason: 'the sweep must reach the empty end of the bar',
        );
        expect(
          readings.reduce((a, b) => a > b ? a : b),
          greaterThan(0.75),
          reason: 'and the full end of it',
        );

        engine.dispose();
      });
    });

    test('a mid-interval sync does not cost the loop its cadence', () {
      fakeAsync((async) {
        final clock = TestClock();
        var ticks = 0;
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 1))),
          onBatch: (batch) => ticks += batch.ticks,
          clock: clock,
        )..start();

        // Sync off the beat over and over, the way the app does on every
        // strike and every purchase.
        for (var i = 0; i < 20; i++) {
          elapse(async, clock, const Duration(milliseconds: 430));
          engine.syncNow();
        }

        expect(
          ticks,
          8,
          reason: '8.6 seconds of a one-second loop is eight whole ticks',
        );
        engine.dispose();
      });
    });
  });
}
