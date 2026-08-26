import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// The naive reference: buy one at a time while the resources last.
///
/// This loop is exactly what the series formulas replace, which makes it the
/// yardstick for whether they are right.
int naiveAffordGeometric(
  double resources,
  double first,
  double growth,
  int owned,
) {
  var left = resources;
  var count = 0;
  var price = first * math.pow(growth, owned);
  while (left >= price) {
    left -= price;
    price *= growth;
    count++;
  }
  return count;
}

int naiveAffordArithmetic(
  double resources,
  double first,
  double step,
  int owned,
) {
  var left = resources;
  var count = 0;
  var price = first + step * owned;
  while (left >= price) {
    left -= price;
    price += step;
    count++;
  }
  return count;
}

BigDouble big(num v) => BigDouble.fromNum(v);

void main() {
  group('sumGeometricSeries', () {
    test('sums the first few purchases', () {
      // 10 + 20 + 40
      expect(
        BigDouble.sumGeometricSeries(big(3), big(10), big(2), big(0)),
        big(70),
      );
    });

    test('starts from what is already owned', () {
      // two already owned, so the next three cost 40 + 80 + 160
      expect(
        BigDouble.sumGeometricSeries(big(3), big(10), big(2), big(2)),
        big(280),
      );
    });

    test('buying nothing costs nothing', () {
      expect(
        BigDouble.sumGeometricSeries(big(0), big(10), big(2), big(5)),
        BigDouble.zero,
      );
    });

    test('degenerates to plain multiplication when growth is one', () {
      expect(
        BigDouble.sumGeometricSeries(big(7), big(10), big(1), big(3)),
        big(70),
      );
    });

    test('handles the growth the game actually uses', () {
      // Drill price in the prototype: 15 * 1.13^n
      var expected = 0.0;
      for (var i = 0; i < 20; i++) {
        expected += 15 * math.pow(1.13, i);
      }

      final got = BigDouble.sumGeometricSeries(
        big(20),
        big(15),
        big(1.13),
        big(0),
      );

      expect(
        got.equalsWithTolerance(big(expected), 1e-9),
        isTrue,
        reason: 'got ${got.toJson()}, expected $expected',
      );
    });
  });

  group('affordGeometricSeries', () {
    test('spends exactly the sum of three purchases', () {
      expect(
        BigDouble.affordGeometricSeries(big(70), big(10), big(2), big(0)),
        big(3),
      );
    });

    test('one unit short buys one fewer', () {
      expect(
        BigDouble.affordGeometricSeries(big(69), big(10), big(2), big(0)),
        big(2),
      );
    });

    test('affords nothing when the first price is out of reach', () {
      expect(
        BigDouble.affordGeometricSeries(big(9), big(10), big(2), big(0)),
        BigDouble.zero,
      );
    });

    test('accounts for what is already owned', () {
      expect(
        BigDouble.affordGeometricSeries(big(280), big(10), big(2), big(2)),
        big(3),
      );
    });

    test('degenerates to division when growth is one', () {
      expect(
        BigDouble.affordGeometricSeries(big(75), big(10), big(1), big(0)),
        big(7),
      );
    });

    test('reaches counts a loop could not afford to compute', () {
      // 1e300 of resources at 1.13 growth: thousands of purchases, no loop.
      final count = BigDouble.affordGeometricSeries(
        BigDouble(1, 300),
        big(15),
        big(1.13),
        big(0),
      );

      expect(count > big(5000), isTrue, reason: 'got ${count.toJson()}');
      // Checked from the inside: that many costs no more than what is on hand,
      // and one more already costs too much.
      final spent = BigDouble.sumGeometricSeries(
        count,
        big(15),
        big(1.13),
        big(0),
      );
      final spentPlusOne = BigDouble.sumGeometricSeries(
        count + BigDouble.one,
        big(15),
        big(1.13),
        big(0),
      );

      expect(spent.lteWithTolerance(BigDouble(1, 300)), isTrue);
      expect(spentPlusOne > BigDouble(1, 300), isTrue);
    });
  });

  group('arithmetic series', () {
    test('sums a linear price ladder', () {
      // 10 + 15 + 20
      expect(
        BigDouble.sumArithmeticSeries(big(3), big(10), big(5), big(0)),
        big(45),
      );
    });

    test('starts from what is already owned', () {
      // two already owned, so the next three cost 20 + 25 + 30
      expect(
        BigDouble.sumArithmeticSeries(big(3), big(10), big(5), big(2)),
        big(75),
      );
    });

    test('affords exactly the sum', () {
      expect(
        BigDouble.affordArithmeticSeries(big(45), big(10), big(5), big(0)),
        big(3),
      );
    });

    test('one unit short buys one fewer', () {
      expect(
        BigDouble.affordArithmeticSeries(big(44), big(10), big(5), big(0)),
        big(2),
      );
    });
  });

  group('agreement with the naive loop', () {
    test('geometric matches buying one at a time', () {
      final rng = math.Random(20260827);

      for (var i = 0; i < 300; i++) {
        final first = rng.nextDouble() * 90 + 10;
        final growth = 1.02 + rng.nextDouble() * 0.5;
        final owned = rng.nextInt(20);
        final resources =
            first * math.pow(growth, owned) * (rng.nextDouble() * 400 + 1);

        final want = naiveAffordGeometric(resources, first, growth, owned);
        final got = BigDouble.affordGeometricSeries(
          big(resources),
          big(first),
          big(growth),
          big(owned),
        );

        expect(
          got,
          big(want),
          reason:
              'resources=$resources first=$first growth=$growth owned=$owned',
        );
      }
    });

    test('arithmetic matches buying one at a time', () {
      final rng = math.Random(20260828);

      for (var i = 0; i < 300; i++) {
        final first = rng.nextDouble() * 90 + 10;
        final step = rng.nextDouble() * 20 + 1;
        final owned = rng.nextInt(20);
        final resources = (first + step * owned) * (rng.nextDouble() * 50 + 1);

        final want = naiveAffordArithmetic(resources, first, step, owned);
        final got = BigDouble.affordArithmeticSeries(
          big(resources),
          big(first),
          big(step),
          big(owned),
        );

        expect(
          got,
          big(want),
          reason: 'resources=$resources first=$first step=$step owned=$owned',
        );
      }
    });
  });
}
