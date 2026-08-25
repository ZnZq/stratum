import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('normalization invariant', () {
    test('pulls an oversized mantissa down into [1, 10)', () {
      final n = BigDouble(1234.5, 2);

      expect(n.mantissa, closeTo(1.2345, 1e-12));
      expect(n.exponent, 5);
    });

    test('pushes an undersized mantissa up into [1, 10)', () {
      final n = BigDouble(0.00042, 10);

      expect(n.mantissa, closeTo(4.2, 1e-12));
      expect(n.exponent, 6);
    });

    test('keeps an already normalized mantissa untouched', () {
      final n = BigDouble(3.75, -4);

      expect(n.mantissa, 3.75);
      expect(n.exponent, -4);
    });

    test('collapses any zero mantissa to the canonical zero', () {
      final n = BigDouble(0, 42);

      expect(n.mantissa, 0.0);
      expect(n.exponent, 0);
    });

    test('carries the sign in the mantissa', () {
      final n = BigDouble(-1234.5, 2);

      expect(n.mantissa, closeTo(-1.2345, 1e-12));
      expect(n.exponent, 5);
      expect(n.isNegative, isTrue);
    });
  });

  group('fromNum', () {
    test('converts a plain int', () {
      final n = BigDouble.fromNum(1500);

      expect(n.mantissa, closeTo(1.5, 1e-12));
      expect(n.exponent, 3);
    });

    test('converts a fractional double', () {
      final n = BigDouble.fromNum(0.25);

      expect(n.mantissa, closeTo(2.5, 1e-12));
      expect(n.exponent, -1);
    });

    test('converts zero to the canonical zero', () {
      expect(BigDouble.fromNum(0).mantissa, 0.0);
      expect(BigDouble.fromNum(0).exponent, 0);
    });
  });

  group('constants', () {
    test('zero and one are canonical', () {
      expect(BigDouble.zero.mantissa, 0.0);
      expect(BigDouble.zero.exponent, 0);
      expect(BigDouble.one.mantissa, 1.0);
      expect(BigDouble.one.exponent, 0);
    });

    test('maxValue sits on the exponent limit', () {
      expect(BigDouble.maxValue.exponent, BigDouble.expLimit);
      expect(BigDouble.maxValue.mantissa, 1.0);
    });

    test('minPositive sits on the negated exponent limit', () {
      expect(BigDouble.minPositive.exponent, -BigDouble.expLimit);
      expect(BigDouble.minPositive.mantissa, 1.0);
    });
  });

  group('toDouble', () {
    test('round-trips values inside the double range', () {
      expect(BigDouble.fromNum(1500).toDouble(), closeTo(1500, 1e-9));
      expect(BigDouble.fromNum(0.25).toDouble(), closeTo(0.25, 1e-15));
      expect(BigDouble.fromNum(-7).toDouble(), closeTo(-7, 1e-12));
      expect(BigDouble.zero.toDouble(), 0.0);
    });
  });

  group('fromMantissaExponent', () {
    test('accepts an already normalized pair and stays const', () {
      const n = BigDouble.fromMantissaExponent(1.5, 3);

      expect(n.mantissa, 1.5);
      expect(n.exponent, 3);
      expect(n, BigDouble(1.5, 3));
    });

    test('accepts canonical zero and negative mantissas', () {
      expect(const BigDouble.fromMantissaExponent(0, 0), BigDouble.zero);
      expect(const BigDouble.fromMantissaExponent(-2.5, 7), BigDouble(-2.5, 7));
    });

    test('guards the invariant it cannot enforce', () {
      // The constructor cannot normalize and stay const, so an assert guards
      // the invariant instead.
      expect(() => BigDouble.fromMantissaExponent(15, 3), throwsA(isA<AssertionError>()));
      expect(() => BigDouble.fromMantissaExponent(0.5, 3), throwsA(isA<AssertionError>()));
      expect(() => BigDouble.fromMantissaExponent(0, 5), throwsA(isA<AssertionError>()));
    });
  });
}
