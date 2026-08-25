import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

const second = Duration(seconds: 1);

void main() {
  group('TickRate', () {
    test('describes one tick per interval by default', () {
      final rate = TickRate(Duration(seconds: 4));

      expect(rate.interval, const Duration(seconds: 4));
      expect(rate.ticksPerFire, 1);
    });

    test('describes several ticks per interval', () {
      final rate = TickRate(Duration(milliseconds: 755), ticksPerFire: 2);

      expect(rate.interval, const Duration(milliseconds: 755));
      expect(rate.ticksPerFire, 2);
    });

    test('rejects a non-positive interval', () {
      expect(() => TickRate(Duration.zero), throwsArgumentError);
      expect(() => TickRate(const Duration(seconds: -1)), throwsArgumentError);
    });

    test('rejects a non-positive tick count', () {
      expect(
        () => TickRate(const Duration(seconds: 1), ticksPerFire: 0),
        throwsArgumentError,
      );
    });

    test('imposes no lower bound on the interval', () {
      // Підлога тіку в одну секунду — правило балансу гри, а не рушія.
      expect(TickRate(const Duration(milliseconds: 1)).interval.inMilliseconds, 1);
    });
  });

  group('advancing', () {
    test('fires nothing before the interval elapses', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      final batch = s.advance(const Duration(seconds: 3));

      expect(batch.ticks, 0);
      expect(batch.consumed, Duration.zero);
      expect(batch.overflow, Duration.zero);
      expect(s.pending, const Duration(seconds: 3));
    });

    test('fires once when the interval is reached exactly', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      final batch = s.advance(const Duration(seconds: 4));

      expect(batch.ticks, 1);
      expect(batch.consumed, const Duration(seconds: 4));
      expect(s.pending, Duration.zero);
    });

    test('keeps the remainder for the next advance', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      final batch = s.advance(const Duration(seconds: 5));

      expect(batch.ticks, 1);
      expect(batch.consumed, const Duration(seconds: 4));
      expect(s.pending, second);
    });

    test('accumulates across several small advances', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      expect(s.advance(const Duration(seconds: 2)).ticks, 0);
      expect(s.advance(const Duration(seconds: 1)).ticks, 0);
      expect(s.advance(second).ticks, 1);
    });

    test('fires several times for a long advance', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      final batch = s.advance(const Duration(seconds: 14));

      expect(batch.ticks, 3);
      expect(batch.consumed, const Duration(seconds: 12));
      expect(s.pending, const Duration(seconds: 2));
    });

    test('multiplies by the ticks-per-fire setting', () {
      final s = TickScheduler(
        rate: TickRate(Duration(milliseconds: 755), ticksPerFire: 2),
      );

      final batch = s.advance(const Duration(milliseconds: 2265)); // рівно 3 інтервали

      expect(batch.ticks, 6);
      expect(batch.consumed, const Duration(milliseconds: 2265));
      expect(s.pending, Duration.zero);
    });

    test('a zero advance changes nothing', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));
      s.advance(const Duration(seconds: 3));

      final batch = s.advance(Duration.zero);

      expect(batch.ticks, 0);
      expect(s.pending, const Duration(seconds: 3));
    });

    test('rejects time running backwards', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      // Монотонний годинник назад не йде — це помилка викликача, а не привід
      // мовчки повернути нуль.
      expect(() => s.advance(const Duration(seconds: -1)), throwsArgumentError);
    });
  });

  group('catch-up cap', () {
    test('stops at the cap and hands the rest back as overflow', () {
      final s = TickScheduler(
        rate: TickRate(Duration(seconds: 4)),
        maxTicksPerAdvance: 3,
      );

      final batch = s.advance(const Duration(seconds: 40));

      expect(batch.ticks, 3);
      expect(batch.consumed, const Duration(seconds: 12));
      expect(batch.overflow, const Duration(seconds: 28));
      expect(s.pending, Duration.zero,
          reason: 'усе, що за капом, віддано назовні, а не залишено всередині');
    });

    test('an eight hour absence does not try to simulate every tick', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));

      final batch = s.advance(const Duration(hours: 8));

      expect(batch.ticks, TickScheduler.defaultMaxTicksPerAdvance);
      expect(batch.overflow, greaterThan(const Duration(hours: 7)));
    });

    test('no overflow when the cap is not reached', () {
      final s = TickScheduler(
        rate: TickRate(Duration(seconds: 4)),
        maxTicksPerAdvance: 100,
      );

      expect(s.advance(const Duration(seconds: 14)).overflow, Duration.zero);
    });

    test('the cap counts ticks, not fires', () {
      final s = TickScheduler(
        rate: TickRate(Duration(seconds: 1), ticksPerFire: 4),
        maxTicksPerAdvance: 10,
      );

      final batch = s.advance(const Duration(seconds: 100));

      expect(batch.ticks, 8, reason: 'два спрацювання по 4 тіки, третє вже за капом');
      expect(batch.consumed, const Duration(seconds: 2));
    });

    test('rejects a non-positive cap', () {
      expect(
        () => TickScheduler(
          rate: TickRate(Duration(seconds: 1)),
          maxTicksPerAdvance: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('time accounting invariant', () {
    test('not a millisecond appears or disappears', () {
      final s = TickScheduler(
        rate: TickRate(Duration(milliseconds: 755), ticksPerFire: 2),
        maxTicksPerAdvance: 7,
      );

      var totalIn = Duration.zero;
      var totalOut = Duration.zero;

      for (final ms in [0, 1, 754, 755, 756, 1510, 9999, 100000, 3, 60000]) {
        final before = s.pending;
        final step = Duration(milliseconds: ms);
        final batch = s.advance(step);

        expect(
          before + step,
          batch.consumed + batch.overflow + s.pending,
          reason: 'крок $ms мс: час не зійшовся',
        );

        totalIn += step;
        totalOut += batch.consumed + batch.overflow;
      }

      expect(totalIn, totalOut + s.pending);
    });
  });

  group('changing the rate', () {
    test('drops the accumulator', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));
      s.advance(const Duration(milliseconds: 3900));

      s.rate = TickRate(second);

      expect(s.pending, Duration.zero,
          reason: 'інакше можна банкувати час на повільному ритмі '
              'й конвертувати його в пачку тіків на швидкому');
      expect(s.advance(const Duration(milliseconds: 999)).ticks, 0);
      expect(s.advance(const Duration(milliseconds: 1)).ticks, 1);
    });

    test('setting the same rate still resets, and says so plainly', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));
      s.advance(const Duration(seconds: 3));

      s.rate = TickRate(Duration(seconds: 4));

      expect(s.pending, Duration.zero);
    });

    test('reset clears the accumulator without touching the rate', () {
      final s = TickScheduler(rate: TickRate(Duration(seconds: 4)));
      s.advance(const Duration(seconds: 3));

      s.reset();

      expect(s.pending, Duration.zero);
      expect(s.rate.interval, const Duration(seconds: 4));
    });
  });

  group('simulating a day of play', () {
    test('runs a hundred thousand ticks in milliseconds', () {
      // Вимога з CLAUDE.md: «симуляція N тіків за мілісекунди» має бути
      // виконуваним тестом, а не побажанням.
      final s = TickScheduler(
        rate: TickRate(Duration(seconds: 4)),
        maxTicksPerAdvance: 1000000,
      );
      final stopwatch = Stopwatch()..start();

      var total = 0;
      for (var i = 0; i < 100000; i++) {
        total += s.advance(const Duration(seconds: 4)).ticks;
      }
      stopwatch.stop();

      expect(total, 100000);
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'зайняло ${stopwatch.elapsedMilliseconds} мс');
    });
  });
}
