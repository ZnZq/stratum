import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  late bool savedStrict;
  late List<String> reported;

  setUp(() {
    savedStrict = BigDouble.strictMode;
    reported = [];
    BigDouble.onDomainError = reported.add;
  });

  tearDown(() {
    BigDouble.strictMode = savedStrict;
    BigDouble.onDomainError = null;
  });

  group('mode detection', () {
    test('defaults to strict wherever asserts are enabled', () {
      // dart test runs with asserts enabled, which is the mode we treat as
      // debug. If that ever changes, better to find out here.
      expect(savedStrict, isTrue);
    });
  });

  group('division by zero in strict mode', () {
    setUp(() => BigDouble.strictMode = true);

    test('throws instead of producing a poisoned value', () {
      expect(() => BigDouble.one / BigDouble.zero, throwsArgumentError);
      expect(() => BigDouble(-3, 5) / BigDouble.zero, throwsArgumentError);
      expect(() => BigDouble.zero / BigDouble.zero, throwsArgumentError);
    });

    test('reciprocal of zero throws too', () {
      expect(BigDouble.zero.reciprocal, throwsArgumentError);
    });
  });

  group('division by zero in lenient mode', () {
    setUp(() => BigDouble.strictMode = false);

    test('saturates keeping the sign of the numerator', () {
      expect(BigDouble.one / BigDouble.zero, BigDouble.maxValue);
      expect(BigDouble(-3, 5) / BigDouble.zero, -BigDouble.maxValue);
    });

    test('zero over zero is zero', () {
      expect(BigDouble.zero / BigDouble.zero, BigDouble.zero);
    });

    test('reports every saturation so it never passes silently', () {
      BigDouble.one / BigDouble.zero;

      expect(reported, hasLength(1));
      expect(reported.single, contains('zero'));
    });
  });

  group('non-finite input in strict mode', () {
    setUp(() => BigDouble.strictMode = true);

    test('rejects NaN', () {
      expect(() => BigDouble.fromNum(double.nan), throwsArgumentError);
      expect(() => BigDouble(double.nan, 5), throwsArgumentError);
    });

    test('rejects infinities', () {
      expect(() => BigDouble.fromNum(double.infinity), throwsArgumentError);
      expect(
        () => BigDouble.fromNum(double.negativeInfinity),
        throwsArgumentError,
      );
    });
  });

  group('non-finite input in lenient mode', () {
    setUp(() => BigDouble.strictMode = false);

    test('turns NaN into zero', () {
      expect(BigDouble.fromNum(double.nan), BigDouble.zero);
    });

    test('turns infinities into the saturated bounds', () {
      expect(BigDouble.fromNum(double.infinity), BigDouble.maxValue);
      expect(BigDouble.fromNum(double.negativeInfinity), -BigDouble.maxValue);
    });

    test('reports each substitution', () {
      BigDouble.fromNum(double.nan);
      BigDouble.fromNum(double.infinity);

      expect(reported, hasLength(2));
    });
  });

  group('exponent overflow saturates in both modes', () {
    for (final strict in [true, false]) {
      test('does not wrap around (strictMode: $strict)', () {
        BigDouble.strictMode = strict;

        final huge =
            BigDouble(1, BigDouble.expLimit) * BigDouble(1, BigDouble.expLimit);

        expect(huge.exponent, BigDouble.expLimit);
        expect(
          huge.isNegative,
          isFalse,
          reason: 'a wrapped int would give a negative exponent',
        );
      });

      test('underflow collapses to zero (strictMode: $strict)', () {
        BigDouble.strictMode = strict;

        final tiny =
            BigDouble(1, -BigDouble.expLimit) *
            BigDouble(1, -BigDouble.expLimit);

        expect(tiny, BigDouble.zero);
      });
    }
  });

  group('logarithms of non-positive values', () {
    test('reject zero and negatives regardless of mode', () {
      for (final strict in [true, false]) {
        BigDouble.strictMode = strict;
        expect(BigDouble.zero.log10, throwsArgumentError);
        expect(BigDouble(-2, 3).log10, throwsArgumentError);
      }
    });
  });
}
