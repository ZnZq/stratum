import 'package:fake_async/fake_async.dart';
import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// A hand-driven clock: what `Stopwatch` does, except time only moves when the
/// test says so.
class TestClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) => _elapsed += by;
}

/// Moves the fake timer and the fake clock together: the engine learns about
/// time from the clock but fires from the timer, so a test must advance both.
void elapseBoth(FakeAsync async, TestClock clock, Duration by) {
  clock.advance(by);
  async.elapse(by);
}

void main() {
  group('lifecycle', () {
    test('does not fire before it is started', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        );

        elapseBoth(async, clock, const Duration(seconds: 20));

        expect(batches, isEmpty);
      });
    });

    test('reports whether it is running', () {
      fakeAsync((async) {
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) {},
          clock: TestClock(),
        );

        expect(engine.isRunning, isFalse);
        engine.start();
        expect(engine.isRunning, isTrue);
        engine.stop();
        expect(engine.isRunning, isFalse);

        engine.dispose();
        async.flushTimers();
      });
    });

    test('starting twice does not double the tick rate', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        engine.start();
        elapseBoth(async, clock, const Duration(seconds: 4));

        expect(batches, hasLength(1));
        engine.dispose();
      });
    });
  });

  group('driving the scheduler', () {
    test('delivers a batch once the interval passes', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(seconds: 4));

        expect(batches, hasLength(1));
        expect(batches.single.ticks, 1);
        engine.dispose();
      });
    });

    test('stays silent while nothing has fired', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        // The timer fires but no time has accumulated. Empty batches are not
        // delivered, since the caller has nothing to do with them.
        async.elapse(const Duration(seconds: 4));

        expect(batches, isEmpty);
        engine.dispose();
      });
    });

    test('keeps delivering over a long run', () {
      fakeAsync((async) {
        final clock = TestClock();
        var ticks = 0;
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (batch) {
            ticks += batch.ticks;
          },
          clock: clock,
        )..start();

        for (var i = 0; i < 10; i++) {
          elapseBoth(async, clock, const Duration(seconds: 4));
        }

        expect(ticks, 10);
        engine.dispose();
      });
    });

    test('stops delivering after stop', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(seconds: 4));
        engine.stop();
        elapseBoth(async, clock, const Duration(seconds: 40));

        expect(batches, hasLength(1));
        engine.dispose();
      });
    });

    test('hands overflow through untouched', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(
            rate: TickRate(const Duration(seconds: 4)),
            maxTicksPerAdvance: 2,
          ),
          onBatch: batches.add,
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(seconds: 40));

        expect(batches.single.ticks, 2);
        expect(batches.single.overflow, const Duration(seconds: 32));
        engine.dispose();
      });
    });
  });

  group('syncNow', () {
    test('settles the accumulated time without waiting for the timer', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        clock.advance(const Duration(seconds: 9));
        engine.syncNow();

        expect(batches.single.ticks, 2);
        engine.dispose();
      });
    });

    test('works even when the engine was never started', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        );

        clock.advance(const Duration(seconds: 8));
        engine.syncNow();

        expect(batches.single.ticks, 2);
        engine.dispose();
      });
    });
  });

  group('changing the rate', () {
    test('retimes the timer around the time already served', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        clock.advance(const Duration(milliseconds: 3900));
        engine.rate = TickRate(const Duration(seconds: 1));

        // 3.9s of a 4s tick is 0.975 of the way there, and that fraction
        // survives the change: 25ms of the new second is all that is left...
        elapseBoth(async, clock, const Duration(milliseconds: 24));
        expect(batches, isEmpty);

        elapseBoth(async, clock, const Duration(milliseconds: 1));
        expect(batches, hasLength(1));

        // ...after which the loop settles into the new period.
        elapseBoth(async, clock, const Duration(seconds: 1));
        expect(batches, hasLength(2));

        engine.dispose();
      });
    });
  });

  group('dispose', () {
    test('cancels the timer', () {
      fakeAsync((async) {
        final clock = TestClock();
        final batches = <TickBatch>[];
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: batches.add,
          clock: clock,
        )..start();

        engine.dispose();
        elapseBoth(async, clock, const Duration(seconds: 40));

        expect(batches, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('refuses to be used afterwards', () {
      fakeAsync((async) {
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) {},
          clock: TestClock(),
        )..dispose();

        expect(engine.start, throwsStateError);
        expect(engine.syncNow, throwsStateError);
      });
    });
  });

  group('the default clock is monotonic', () {
    test('a real engine measures with Stopwatch, not DateTime', () {
      // Wall-clock time jumps: NTP corrects it, the player changes time zone or
      // deliberately moves it forward to farm resources.
      expect(StopwatchClock(), isA<MonotonicClock>());
      final clock = StopwatchClock();
      expect(clock.elapsed, greaterThanOrEqualTo(Duration.zero));
    });
  });

  group('progress toward the next tick', () {
    TickEngine engineOn(
      TestClock clock, {
      Duration interval = const Duration(seconds: 4),
      int ticksPerFire = 1,
    }) => TickEngine(
      scheduler: TickScheduler(
        rate: TickRate(interval, ticksPerFire: ticksPerFire),
      ),
      onBatch: (_) {},
      clock: clock,
    );

    test('starts empty', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        expect(engine.progress, 0);
        engine.dispose();
      });
    });

    test('fills as the clock moves, without waiting for the timer', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        // Only the clock moves here. The scheduler learns nothing until the
        // timer fires, so a progress bar reading its accumulator would sit at
        // zero for the whole interval and then jump.
        clock.advance(const Duration(seconds: 1));
        expect(engine.progress, closeTo(0.25, 1e-9));

        clock.advance(const Duration(seconds: 1));
        expect(engine.progress, closeTo(0.5, 1e-9));

        clock.advance(const Duration(milliseconds: 1900));
        expect(engine.progress, closeTo(0.975, 1e-9));

        engine.dispose();
      });
    });

    test('empties again once the tick fires', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        elapseBoth(async, clock, const Duration(seconds: 4));

        expect(engine.progress, closeTo(0, 1e-9));
        engine.dispose();
      });
    });

    test('clamps at full rather than wrapping around', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        // A late timer must show a full bar waiting to fire, not a bar that
        // silently restarted without a tick having happened.
        clock.advance(const Duration(seconds: 10));

        expect(engine.progress, 1.0);
        engine.dispose();
      });
    });

    test('measures the interval, not a single tick within it', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(
          clock,
          interval: const Duration(seconds: 2),
          ticksPerFire: 4,
        );

        engine.start();
        clock.advance(const Duration(seconds: 1));

        expect(engine.progress, closeTo(0.5, 1e-9));
        engine.dispose();
      });
    });

    test('freezes while the engine is stopped', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        clock.advance(const Duration(seconds: 2));
        engine.stop();
        clock.advance(const Duration(seconds: 2));

        expect(
          engine.progress,
          closeTo(0.5, 1e-9),
          reason: 'a paused game must not keep filling the bar',
        );
        engine.dispose();
      });
    });

    test('resumes from where it froze', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        clock.advance(const Duration(seconds: 3));
        engine.stop();
        clock.advance(const Duration(hours: 1));
        engine.start();

        expect(
          engine.progress,
          closeTo(0.75, 1e-9),
          reason: 'time spent paused is discarded, banked progress is not',
        );
        engine.dispose();
      });
    });

    test('keeps its fill when the rate changes', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock)..start();

        clock.advance(const Duration(seconds: 3));
        engine.rate = TickRate(const Duration(seconds: 1));

        expect(
          engine.progress,
          closeTo(0.75, 1e-9),
          reason:
              'three quarters of a 4s tick is three quarters of a 1s '
              'tick -- the bar carries on, it does not start over',
        );

        clock.advance(const Duration(milliseconds: 125));
        expect(engine.progress, closeTo(0.875, 1e-9));

        engine.dispose();
      });
    });

    test('reads zero before the engine ever starts', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = engineOn(clock);

        clock.advance(const Duration(seconds: 2));

        expect(engine.progress, 0);
        engine.dispose();
      });
    });
  });

  group('time to the next tick', () {
    test('counts down as progress fills', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) {},
          clock: clock,
        )..start();

        expect(engine.timeToNextTick, const Duration(seconds: 4));

        clock.advance(const Duration(seconds: 1));
        expect(engine.timeToNextTick, const Duration(seconds: 3));

        clock.advance(const Duration(milliseconds: 2500));
        expect(engine.timeToNextTick, const Duration(milliseconds: 500));

        engine.dispose();
      });
    });

    test('never goes negative', () {
      fakeAsync((async) {
        final clock = TestClock();
        final engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) {},
          clock: clock,
        )..start();

        clock.advance(const Duration(seconds: 30));

        expect(engine.timeToNextTick, Duration.zero);
        engine.dispose();
      });
    });
  });

  group('reading a disposed engine', () {
    test(
      'is an error, so a stray animation frame surfaces the lifecycle bug',
      () {
        fakeAsync((async) {
          final engine = TickEngine(
            scheduler: TickScheduler(
              rate: TickRate(const Duration(seconds: 4)),
            ),
            onBatch: (_) {},
            clock: TestClock(),
          )..dispose();

          expect(() => engine.progress, throwsStateError);
          expect(() => engine.timeToNextTick, throwsStateError);
        });
      },
    );
  });

  group('stopping from inside the callback', () {
    test('does not re-enter the callback', () {
      fakeAsync((async) {
        final clock = TestClock();
        var calls = 0;
        late TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) {
            calls++;
            // Real time keeps passing while a callback runs, so by the moment
            // stop() syncs, another whole interval may be owed.
            clock.advance(const Duration(seconds: 4));
            engine.stop();
          },
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(seconds: 4));

        expect(calls, 1, reason: 'stop() inside onBatch must not recurse');
        engine.dispose();
      });
    });

    test('still stops', () {
      fakeAsync((async) {
        final clock = TestClock();
        late TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (_) => engine.stop(),
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(seconds: 4));

        expect(engine.isRunning, isFalse);
        engine.dispose();
      });
    });
  });

  group('a forcing charge on its own loop', () {
    test('stops at the cap and resumes once the player spends', () {
      fakeAsync((async) {
        const cap = 5;
        final clock = TestClock();
        var charge = 0;
        late TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(minutes: 1))),
          onBatch: (batch) {
            charge += batch.ticks;
            if (charge >= cap) {
              charge = cap;
              engine.stop();
            }
          },
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(minutes: 10));

        expect(charge, cap);
        expect(
          engine.isRunning,
          isFalse,
          reason: 'a full charge has nothing left to regenerate',
        );

        // Nothing accrues while the loop sleeps, however long it sleeps.
        elapseBoth(async, clock, const Duration(hours: 3));
        expect(charge, cap);

        charge -= 3;
        engine.start();
        elapseBoth(async, clock, const Duration(minutes: 2));

        expect(charge, 4);
        expect(engine.isRunning, isTrue);
        engine.dispose();
      });
    });

    test('the progress bar freezes while the charge sits at the cap', () {
      fakeAsync((async) {
        final clock = TestClock();
        late TickEngine engine;
        engine = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(minutes: 1))),
          onBatch: (_) => engine.stop(),
          clock: clock,
        )..start();

        elapseBoth(async, clock, const Duration(minutes: 1));
        final frozen = engine.progress;
        elapseBoth(async, clock, const Duration(minutes: 30));

        expect(
          engine.progress,
          frozen,
          reason: 'a still bar tells the player they are capped',
        );
        engine.dispose();
      });
    });

    test('runs at its own rhythm, independent of the drill loop', () {
      fakeAsync((async) {
        final clock = TestClock();
        var drillTicks = 0;
        var chargeTicks = 0;

        final drill = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(seconds: 4))),
          onBatch: (b) => drillTicks += b.ticks,
          clock: clock,
        )..start();
        final charge = TickEngine(
          scheduler: TickScheduler(rate: TickRate(const Duration(minutes: 1))),
          onBatch: (b) => chargeTicks += b.ticks,
          clock: clock,
        )..start();

        // Stepped rather than jumped: one five-minute leap would hit the
        // catch-up cap and measure that instead of the two rhythms.
        for (var i = 0; i < 75; i++) {
          elapseBoth(async, clock, const Duration(seconds: 4));
        }

        expect(drillTicks, 75);
        expect(chargeTicks, 5);

        drill.dispose();
        charge.dispose();
      });
    });
  });
}
