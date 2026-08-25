import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Compares with a relative tolerance: the mantissa carries ~15 significant
/// digits, so exact equality cannot be demanded of transcendental functions.
void expectClose(BigDouble got, BigDouble want, {double tolerance = 1e-12}) {
  final relative =
      (got.toDouble() - want.toDouble()).abs() / want.toDouble().abs();
  expect(relative, lessThan(tolerance), reason: 'got $got, expected $want');
}

void main() {
  group('log10', () {
    test('reads the exponent of a clean power of ten', () {
      expect(BigDouble(1, 50).log10(), closeTo(50, 1e-12));
      expect(BigDouble(1, -7).log10(), closeTo(-7, 1e-12));
    });

    test('folds the mantissa into the result', () {
      expect(BigDouble(2, 0).log10(), closeTo(0.301029995663981, 1e-12));
      expect(BigDouble(5, 3).log10(), closeTo(3.698970004336019, 1e-12));
    });

    test('stays exact at the exponent limit', () {
      // expLimit = 9e15 sits below 2^53 and so fits a double exactly, which is
      // why log10 is allowed to return a plain double.
      expect(BigDouble.maxValue.log10(), BigDouble.expLimit.toDouble());
    });

    test('log10 of one is zero', () {
      expect(BigDouble.one.log10(), 0.0);
    });
  });

  group('ln and log', () {
    test('ln matches the natural logarithm', () {
      expect(BigDouble.fromNum(math.e).ln(), closeTo(1, 1e-12));
      expect(BigDouble(1, 10).ln(), closeTo(10 * math.ln10, 1e-12));
    });

    test('log takes an arbitrary base', () {
      expect(BigDouble.fromNum(8).log(2), closeTo(3, 1e-12));
      expect(BigDouble.fromNum(81).log(3), closeTo(4, 1e-12));
    });
  });

  group('pow', () {
    test('raising to zero gives one', () {
      expect(BigDouble(7.3, 42).pow(0), BigDouble.one);
      expect(BigDouble.zero.pow(0), BigDouble.one);
    });

    test('raising to one is identity', () {
      expectClose(BigDouble(7.3, 42).pow(1), BigDouble(7.3, 42));
    });

    test('raises small integers exactly enough', () {
      expectClose(BigDouble.fromNum(2).pow(10), BigDouble.fromNum(1024));
    });

    test('reaches exponents no double could hold', () {
      final r = BigDouble.fromNum(10).pow(1000);

      expect(r.exponent, 1000);
      expect(r.mantissa, closeTo(1, 1e-9));
    });

    test('handles the growth curves the game actually uses', () {
      // Drill price in the prototype: 15 * 1.13^n
      expectClose(
        BigDouble.fromNum(1.13).pow(200),
        BigDouble.fromNum(math.pow(1.13, 200)),
        tolerance: 1e-10,
      );
      // Layer density: 1.055^metres
      expectClose(
        BigDouble.fromNum(1.055).pow(500),
        BigDouble.fromNum(math.pow(1.055, 500)),
        tolerance: 1e-10,
      );
    });

    test('accepts fractional powers', () {
      // Quantonium capsules: quantonium^0.8
      expectClose(
        BigDouble.fromNum(1000).pow(0.8),
        BigDouble.fromNum(math.pow(1000, 0.8)),
        tolerance: 1e-10,
      );
    });

    test('accepts negative powers', () {
      expectClose(BigDouble.fromNum(2).pow(-3), BigDouble.fromNum(0.125));
    });

    test('zero to a positive power is zero', () {
      expect(BigDouble.zero.pow(3), BigDouble.zero);
    });

    test('keeps the sign for odd integer powers of a negative base', () {
      expectClose(BigDouble.fromNum(-2).pow(3), BigDouble.fromNum(-8));
      expectClose(BigDouble.fromNum(-2).pow(4), BigDouble.fromNum(16));
    });

    test('rejects a fractional power of a negative base', () {
      expect(() => BigDouble.fromNum(-2).pow(0.5), throwsArgumentError);
    });

    test('saturates instead of wrapping when the exponent overflows', () {
      final r = BigDouble.fromNum(10).pow(1e17);

      expect(r.exponent, BigDouble.expLimit);
      expect(r.isNegative, isFalse);
    });
  });

  group('sqrt', () {
    test('halves a clean exponent', () {
      expectClose(BigDouble(1, 100).sqrt(), BigDouble(1, 50));
    });

    test('takes the root of a plain value', () {
      expectClose(BigDouble.fromNum(4).sqrt(), BigDouble.fromNum(2));
      expectClose(BigDouble.fromNum(2).sqrt(), BigDouble.fromNum(math.sqrt2));
    });

    test('sqrt of zero is zero', () {
      expect(BigDouble.zero.sqrt(), BigDouble.zero);
    });

    test('rejects a negative radicand', () {
      expect(() => BigDouble.fromNum(-4).sqrt(), throwsArgumentError);
    });
  });

  group('pow oracle', () {
    test('matches math.pow wherever a plain double still holds the result', () {
      final rng = math.Random(20260826);

      for (var i = 0; i < 1000; i++) {
        final base = rng.nextDouble() * 5 + 0.1;
        final power = rng.nextDouble() * 20 - 10;
        final want = math.pow(base, power).toDouble();
        if (!want.isFinite || want == 0) continue;

        final got = BigDouble.fromNum(base).pow(power);
        final relative = (got.toDouble() - want).abs() / want.abs();

        expect(relative, lessThan(1e-10), reason: '$base ^ $power');
      }
    });
  });
}
