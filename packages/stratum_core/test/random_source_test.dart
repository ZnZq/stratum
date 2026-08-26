import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

List<double> draw(RandomStream stream, int count) =>
    List.generate(count, (_) => stream.nextDouble());

void main() {
  group('determinism', () {
    test('the same seed replays the same sequence', () {
      final a = RandomStream.seeded(12345);
      final b = RandomStream.seeded(12345);

      expect(draw(a, 50), draw(b, 50));
    });

    test('different seeds diverge', () {
      final a = RandomStream.seeded(1);
      final b = RandomStream.seeded(2);

      expect(draw(a, 50), isNot(draw(b, 50)));
    });

    test('a zero seed still produces a usable sequence', () {
      // An all-zero state is the one thing xorshift cannot recover from.
      final values = draw(RandomStream.seeded(0), 20).toSet();

      expect(values.length, greaterThan(15));
    });
  });

  group('nextDouble', () {
    test('stays inside [0, 1)', () {
      final stream = RandomStream.seeded(7);

      for (var i = 0; i < 10000; i++) {
        final v = stream.nextDouble();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('spreads roughly evenly across ten buckets', () {
      final stream = RandomStream.seeded(99);
      final buckets = List.filled(10, 0);

      for (var i = 0; i < 100000; i++) {
        buckets[(stream.nextDouble() * 10).floor()]++;
      }

      for (final count in buckets) {
        expect(count, greaterThan(9000), reason: 'buckets: $buckets');
        expect(count, lessThan(11000), reason: 'buckets: $buckets');
      }
    });
  });

  group('nextInt', () {
    test('stays inside [0, max)', () {
      final stream = RandomStream.seeded(3);

      for (var i = 0; i < 10000; i++) {
        final v = stream.nextInt(6);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(6));
      }
    });

    test('reaches both ends of the range', () {
      final stream = RandomStream.seeded(3);
      final seen = <int>{};

      for (var i = 0; i < 1000; i++) {
        seen.add(stream.nextInt(6));
      }

      expect(seen, {0, 1, 2, 3, 4, 5});
    });

    test('rejects a non-positive bound', () {
      final stream = RandomStream.seeded(3);

      expect(() => stream.nextInt(0), throwsArgumentError);
      expect(() => stream.nextInt(-1), throwsArgumentError);
    });
  });

  group('chance', () {
    test('never fires at zero and always fires at one', () {
      final stream = RandomStream.seeded(11);

      for (var i = 0; i < 1000; i++) {
        expect(stream.chance(0), isFalse);
        expect(stream.chance(1), isTrue);
      }
    });

    test('fires about as often as asked', () {
      final stream = RandomStream.seeded(2026);
      var hits = 0;

      for (var i = 0; i < 100000; i++) {
        if (stream.chance(0.05)) hits++;
      }

      expect(hits, greaterThan(4700), reason: 'hits: $hits');
      expect(hits, lessThan(5300), reason: 'hits: $hits');
    });

    test('always consumes a draw, whatever the probability', () {
      // The property that keeps sequences stable when a balance number changes:
      // dropping a crit chance to zero must not shift every later roll.
      final withZero = RandomStream.seeded(5);
      final plain = RandomStream.seeded(5);

      withZero.chance(0);
      plain.nextDouble();

      expect(withZero.nextDouble(), plain.nextDouble());
    });

    test('rejects a probability outside [0, 1]', () {
      final stream = RandomStream.seeded(5);

      expect(() => stream.chance(-0.1), throwsArgumentError);
      expect(() => stream.chance(1.1), throwsArgumentError);
    });
  });

  group('range', () {
    test('stays within the bounds', () {
      final stream = RandomStream.seeded(8);

      for (var i = 0; i < 1000; i++) {
        final v = stream.range(10, 20);
        expect(v, greaterThanOrEqualTo(10.0));
        expect(v, lessThan(20.0));
      }
    });

    test('rejects an inverted range', () {
      expect(() => RandomStream.seeded(8).range(20, 10), throwsArgumentError);
    });
  });

  group('stream serialization', () {
    test('restores mid-sequence and continues identically', () {
      final original = RandomStream.seeded(777);
      draw(original, 17);

      final restored = RandomStream.fromJson(original.toJson());

      expect(draw(restored, 25), draw(original, 25));
    });

    test('round-trips through the wire format', () {
      final stream = RandomStream.seeded(777);
      draw(stream, 3);

      expect(RandomStream.fromJson(stream.toJson()).toJson(), stream.toJson());
    });
  });

  group('named streams', () {
    test('different names give different sequences', () {
      final source = RandomSource(seed: 42);

      expect(
        draw(source.stream('crit'), 20),
        isNot(draw(source.stream('echo'), 20)),
      );
    });

    test('the same name gives the same stream object', () {
      final source = RandomSource(seed: 42);

      expect(identical(source.stream('crit'), source.stream('crit')), isTrue);
    });

    test('the same seed and name replay the same sequence', () {
      expect(
        draw(RandomSource(seed: 42).stream('crit'), 20),
        draw(RandomSource(seed: 42).stream('crit'), 20),
      );
    });

    test('adding a consumer does not disturb the existing ones', () {
      // The whole point of substreams. With one shared stream, introducing a
      // new roll anywhere in the tick would shift every roll after it and turn
      // every parity test red.
      final before = draw(RandomSource(seed: 42).stream('crit'), 20);

      final later = RandomSource(seed: 42);
      later.stream('echo').nextDouble();
      later.stream('quantonium').nextDouble();

      expect(draw(later.stream('crit'), 20), before);
    });

    test('a different master seed changes every substream', () {
      expect(
        draw(RandomSource(seed: 1).stream('crit'), 20),
        isNot(draw(RandomSource(seed: 2).stream('crit'), 20)),
      );
    });
  });

  group('source serialization', () {
    test('restores every stream where it stood', () {
      final source = RandomSource(seed: 42);
      draw(source.stream('crit'), 5);
      draw(source.stream('echo'), 9);

      final restored = RandomSource.fromJson(source.toJson());

      expect(
        draw(restored.stream('crit'), 10),
        draw(source.stream('crit'), 10),
      );
      expect(
        draw(restored.stream('echo'), 10),
        draw(source.stream('echo'), 10),
      );
    });

    test('a stream absent from the save starts from its derived seed', () {
      final saved = RandomSource(seed: 42);
      draw(saved.stream('crit'), 5);

      final restored = RandomSource.fromJson(saved.toJson());

      // 'echo' was never touched before saving, so it must behave exactly as it
      // would in a fresh source with the same master seed.
      expect(
        draw(restored.stream('echo'), 20),
        draw(RandomSource(seed: 42).stream('echo'), 20),
      );
    });

    test('keeps the master seed across a round trip', () {
      final source = RandomSource(seed: 4242);

      expect(RandomSource.fromJson(source.toJson()).seed, 4242);
    });
  });

  group('bit level quality', () {
    test('every mantissa bit is close to balanced', () {
      // A shift or mask mistake shows up here and nowhere else: a sequence with
      // a stuck or lopsided bit still passes a bucket test on the whole value.
      final stream = RandomStream.seeded(31337);
      final ones = List.filled(53, 0);
      const draws = 50000;

      for (var i = 0; i < draws; i++) {
        final bits = (stream.nextDouble() * (1 << 53)).toInt();
        for (var bit = 0; bit < 53; bit++) {
          if ((bits >> bit) & 1 == 1) ones[bit]++;
        }
      }

      for (var bit = 0; bit < 53; bit++) {
        expect(
          ones[bit] / draws,
          closeTo(0.5, 0.02),
          reason: 'bit $bit is skewed',
        );
      }
    });

    test('consecutive draws are not correlated', () {
      final stream = RandomStream.seeded(4242);
      var rising = 0;
      const pairs = 50000;
      var previous = stream.nextDouble();

      for (var i = 0; i < pairs; i++) {
        final current = stream.nextDouble();
        if (current > previous) rising++;
        previous = current;
      }

      expect(rising / pairs, closeTo(0.5, 0.02));
    });
  });

  group('streams are independent of one another', () {
    test('two substreams agree about half the time, as strangers should', () {
      final source = RandomSource(seed: 2026);
      final crit = source.stream('crit');
      final echo = source.stream('echo');
      var agreements = 0;
      const rolls = 50000;

      for (var i = 0; i < rolls; i++) {
        if (crit.chance(0.5) == echo.chance(0.5)) agreements++;
      }

      expect(
        agreements / rolls,
        closeTo(0.5, 0.02),
        reason: 'correlated substreams would sit far from a half',
      );
    });

    test('names one character apart do not track each other', () {
      final source = RandomSource(seed: 1);

      expect(
        draw(source.stream('crit1'), 20),
        isNot(draw(source.stream('crit2'), 20)),
      );
    });
  });

  group('the all-zero state guard', () {
    test('a restored all-zero state still produces randomness', () {
      // xorshift can never leave an all-zero state: every draw would be zero
      // forever. A corrupted or hand-written save must not brick the run.
      final stream = RandomStream.fromJson([0, 0]);

      expect(draw(stream, 20).toSet().length, greaterThan(15));
    });

    test('rejects a malformed state', () {
      expect(() => RandomStream.fromJson([1]), throwsFormatException);
      expect(() => RandomStream.fromJson([1, 2, 3]), throwsFormatException);
    });
  });
}
