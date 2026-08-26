import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('equality', () {
    test(
      'two numbers built from different shapes of the same value are equal',
      () {
        expect(BigDouble(1234.5, 2), BigDouble(1.2345, 5));
      },
    );

    test('equal numbers share a hashCode', () {
      expect(BigDouble(1234.5, 2).hashCode, BigDouble(1.2345, 5).hashCode);
    });

    test('same mantissa but different exponent is not equal', () {
      expect(BigDouble(1.5, 3) == BigDouble(1.5, 4), isFalse);
    });

    test('sign is part of equality', () {
      expect(BigDouble(1.5, 3) == BigDouble(-1.5, 3), isFalse);
    });

    test('every zero is the same zero', () {
      expect(BigDouble(0, 99), BigDouble.zero);
    });
  });

  group('ordering', () {
    test('orders by exponent when signs match', () {
      expect(BigDouble(1, 5) > BigDouble(9, 4), isTrue);
      expect(BigDouble(9, 4) < BigDouble(1, 5), isTrue);
    });

    test('orders by mantissa when exponents match', () {
      expect(BigDouble(3, 7) > BigDouble(2, 7), isTrue);
    });

    test('any negative is below any positive', () {
      expect(BigDouble(-1, 100) < BigDouble(1, -100), isTrue);
    });

    test('orders negatives by magnitude in reverse', () {
      expect(BigDouble(-1, 5) < BigDouble(-9, 4), isTrue);
    });

    test('zero sits between negatives and positives', () {
      expect(BigDouble.zero > BigDouble(-1, -50), isTrue);
      expect(BigDouble.zero < BigDouble(1, -50), isTrue);
    });

    test('gte and lte accept equality', () {
      expect(BigDouble(5, 3) >= BigDouble(5, 3), isTrue);
      expect(BigDouble(5, 3) <= BigDouble(5, 3), isTrue);
    });

    test('compareTo reports -1, 0 and 1', () {
      expect(BigDouble(1, 5).compareTo(BigDouble(1, 6)), -1);
      expect(BigDouble(1, 5).compareTo(BigDouble(1, 5)), 0);
      expect(BigDouble(1, 6).compareTo(BigDouble(1, 5)), 1);
    });

    test('sorts a list correctly', () {
      final list = [
        BigDouble(1, 3),
        BigDouble(-5, 9),
        BigDouble.zero,
        BigDouble(2, 3),
        BigDouble(1, 9),
      ]..sort();

      expect(list, [
        BigDouble(-5, 9),
        BigDouble.zero,
        BigDouble(1, 3),
        BigDouble(2, 3),
        BigDouble(1, 9),
      ]);
    });
  });

  group('sign operations', () {
    test('abs strips the sign', () {
      expect(BigDouble(-3.5, 7).abs(), BigDouble(3.5, 7));
      expect(BigDouble.zero.abs(), BigDouble.zero);
    });

    test('unary minus flips the sign', () {
      expect(-BigDouble(3.5, 7), BigDouble(-3.5, 7));
    });

    test('negating zero stays canonical zero', () {
      expect(-BigDouble.zero, BigDouble.zero);
      expect((-BigDouble.zero).mantissa, 0.0);
    });

    test('sign reports -1, 0 and 1', () {
      expect(BigDouble(-2, 4).sign, -1);
      expect(BigDouble.zero.sign, 0);
      expect(BigDouble(2, 4).sign, 1);
    });
  });

  group('min and max', () {
    test('pick the smaller and the larger', () {
      final a = BigDouble(1, 5);
      final b = BigDouble(9, 4);

      expect(a.min(b), b);
      expect(a.max(b), a);
    });

    test('clamp holds a value inside bounds', () {
      final low = BigDouble(1, 0);
      final high = BigDouble(1, 3);

      expect(BigDouble(5, -2).clamp(low, high), low);
      expect(BigDouble(5, 9).clamp(low, high), high);
      expect(BigDouble(5, 1).clamp(low, high), BigDouble(5, 1));
    });
  });
}
