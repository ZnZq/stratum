import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('floor', () {
    test('drops the fractional part downwards', () {
      expect(BigDouble.fromNum(3.7).floor(), BigDouble.fromNum(3));
      expect(BigDouble.fromNum(3.2).floor(), BigDouble.fromNum(3));
    });

    test('rounds negatives away from zero', () {
      expect(BigDouble.fromNum(-3.2).floor(), BigDouble.fromNum(-4));
    });

    test('leaves a value with no representable fraction untouched', () {
      // Past the significant digits there simply is no fractional part.
      expect(BigDouble(1.5, 50).floor(), BigDouble(1.5, 50));
    });

    test('floor of zero is zero', () {
      expect(BigDouble.zero.floor(), BigDouble.zero);
    });
  });

  group('ceil', () {
    test('lifts the fractional part upwards', () {
      expect(BigDouble.fromNum(3.2).ceil(), BigDouble.fromNum(4));
      expect(BigDouble.fromNum(-3.7).ceil(), BigDouble.fromNum(-3));
    });
  });

  group('round', () {
    test('rounds to the nearest integer', () {
      expect(BigDouble.fromNum(3.4).round(), BigDouble.fromNum(3));
      expect(BigDouble.fromNum(3.5).round(), BigDouble.fromNum(4));
      expect(BigDouble.fromNum(-3.5).round(), BigDouble.fromNum(-4));
    });
  });

  group('truncate', () {
    test('cuts towards zero', () {
      expect(BigDouble.fromNum(3.7).truncate(), BigDouble.fromNum(3));
      expect(BigDouble.fromNum(-3.7).truncate(), BigDouble.fromNum(-3));
    });
  });

  group('serialization', () {
    test('writes mantissa and exponent', () {
      expect(BigDouble(1.5, 3).toJson(), '1.5e3');
      expect(BigDouble(-2.25, -7).toJson(), '-2.25e-7');
    });

    test('writes zero canonically', () {
      // The mantissa is a double, so it always prints a decimal point.
      expect(BigDouble.zero.toJson(), '0.0e0');
      expect(BigDouble.one.toJson(), '1.0e0');
    });

    test('round-trips through parse', () {
      for (final n in [
        BigDouble(1.5, 3),
        BigDouble(-2.25, -7),
        BigDouble.zero,
        BigDouble.one,
        BigDouble.maxValue,
        BigDouble.minPositive,
        BigDouble(9.999999999999, 12345),
      ]) {
        expect(BigDouble.parse(n.toJson()), n, reason: 'did not survive the round trip: $n');
      }
    });

    test('parses a plain number without an exponent', () {
      expect(BigDouble.parse('1500'), BigDouble(1.5, 3));
      expect(BigDouble.parse('-0.25'), BigDouble(-2.5, -1));
    });

    test('parses the capital E form', () {
      expect(BigDouble.parse('1.5E3'), BigDouble(1.5, 3));
    });

    test('parses a denormalized literal by normalizing it', () {
      expect(BigDouble.parse('1234.5e2'), BigDouble(1.2345, 5));
    });

    test('rejects garbage', () {
      expect(() => BigDouble.parse('not a number'), throwsFormatException);
      expect(() => BigDouble.parse(''), throwsFormatException);
      expect(() => BigDouble.parse('1.5e'), throwsFormatException);
    });

    test('tryParse returns null instead of throwing', () {
      expect(BigDouble.tryParse('not a number'), isNull);
      expect(BigDouble.tryParse('1.5e3'), BigDouble(1.5, 3));
    });

    test('fromJson is parse', () {
      expect(BigDouble.fromJson('1.5e3'), BigDouble(1.5, 3));
    });
  });
}
