import 'package:fake_async/fake_async.dart';
import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Керований годинник для тестів: те саме, що робить `Stopwatch`, але час
/// рухається лише тоді, коли ми йому скажемо.
class TestClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration by) => _elapsed += by;
}

/// Зводить фейковий таймер і фейковий годинник докупи: рушій дізнається про час
/// із годинника, а спрацьовує від таймера, тож у тесті рухати треба обидва.
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

        // Таймер спрацьовує, але часу ще не набралось — порожні пачки назовні
        // не віддаються, бо викликачеві нема чого з ними робити.
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
          onBatch: (batch) { ticks += batch.ticks; },
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
    test('retimes the timer and drops the accumulator', () {
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

        // Накопичене згоріло разом зі старим ритмом, тож перша секунда після
        // зміни ще нічого не дає...
        elapseBoth(async, clock, const Duration(milliseconds: 999));
        expect(batches, isEmpty);

        // ...а ось на повній секунді нового ритму тік уже є.
        elapseBoth(async, clock, const Duration(milliseconds: 1));
        expect(batches, hasLength(1));

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
      // Настінний годинник стрибає: NTP підкручує, гравець міняє часовий пояс
      // або свідомо переводить час уперед, щоб накрутити ресурси.
      expect(StopwatchClock(), isA<MonotonicClock>());
      final clock = StopwatchClock();
      expect(clock.elapsed, greaterThanOrEqualTo(Duration.zero));
    });
  });
}
