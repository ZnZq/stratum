import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  late NumberStyle savedGlobal;

  setUp(() => savedGlobal = NumberStyle.global);
  tearDown(() => NumberStyle.global = savedGlobal);

  group('compact notation', () {
    String f(num v) => BigDouble.fromNum(v).toString(NumberStyle.compact);

    test('prints small values plainly', () {
      expect(f(0), '0');
      expect(f(7), '7');
      expect(f(42), '42');
      expect(f(999), '999');
    });

    test('keeps one decimal for fractional small values', () {
      expect(f(3.7), '3.7');
      expect(f(0.5), '0.5');
    });

    test('switches to suffixes at a thousand', () {
      expect(f(1000), '1k');
      expect(f(1500), '1.5k');
      expect(f(150000), '150k');
    });

    test('walks the whole suffix table', () {
      // Точним конструюванням, а не літералами: `1e24` у double — це насправді
      // 9.99999999999999983e23, і таблиця перевірялась би не на тому числі.
      String e(int exponent) =>
          BigDouble(1, exponent).toString(NumberStyle.compact);

      expect(e(3), '1k');
      expect(e(6), '1m');
      expect(e(9), '1b');
      expect(e(12), '1t');
      expect(e(15), '1qa');
      expect(e(18), '1qu');
      expect(e(21), '1sx');
      expect(e(24), '1sp');
      expect(e(27), '1o');
      expect(e(30), '1n');
      expect(e(33), '1d');
    });

    test('covers the middle of each tier', () {
      expect(BigDouble(1.5, 4).toString(NumberStyle.compact), '15k');
      expect(BigDouble(1.5, 5).toString(NumberStyle.compact), '150k');
      expect(BigDouble(2.25, 7).toString(NumberStyle.compact), '22.5m');
    });

    test('promotes the tier when rounding pushes the mantissa to a thousand', () {
      // 9.99999e23 у щаблі sx — це 999.999, що з двома знаками округлюється до
      // 1000.00. Надрукувати це як «1000sx» замість «1sp» було б помилкою.
      expect(BigDouble(9.99999, 23).toString(NumberStyle.compact), '1sp');
      expect(BigDouble(9.99999, 5).toString(NumberStyle.compact), '1m');
    });

    test('promotes past the end of the table into scientific', () {
      expect(BigDouble(9.99999, 35).toString(NumberStyle.compact), '1e36');
    });

    test('falls back to scientific past the end of the table', () {
      expect(BigDouble(1, 36).toString(NumberStyle.compact), '1e36');
      expect(BigDouble(2.5, 100).toString(NumberStyle.compact), '2.5e100');
    });

    test('carries the sign', () {
      expect(f(-1500), '-1.5k');
      expect(f(-42), '-42');
    });

    test('reaches magnitudes no double could hold', () {
      expect(BigDouble(3.25, 1000).toString(NumberStyle.compact), '3.25e1000');
    });
  });

  group('scientific notation', () {
    String f(BigDouble v) => v.toString(NumberStyle.scientific);

    test('always uses the exponent form above the plain threshold', () {
      expect(f(BigDouble(1.5, 3)), '1.5e3');
      expect(f(BigDouble(1.23, 45)), '1.23e45');
    });

    test('still prints small values plainly', () {
      expect(f(BigDouble.fromNum(42)), '42');
      expect(f(BigDouble.zero), '0');
    });

    test('carries the sign', () {
      expect(f(BigDouble(-1.5, 3)), '-1.5e3');
    });
  });

  group('integer notation', () {
    String f(num v) => BigDouble.fromNum(v).toString(NumberStyle.integer);

    test('prints whole digits without suffixes', () {
      // Глибина в метрах має читатись метрами, а не як 1.5k.
      expect(f(1523), '1523');
      expect(f(0), '0');
      expect(f(999999), '999999');
    });

    test('drops the fraction', () {
      expect(f(3.7), '4');
      expect(f(3.2), '3');
    });
  });

  group('style precedence', () {
    test('an explicit argument beats everything', () {
      final n = BigDouble(1.5, 3).withStyle(NumberStyle.compact);
      NumberStyle.global = NumberStyle.compact;

      expect(n.toString(NumberStyle.scientific), '1.5e3');
    });

    test('the number own style beats the global one', () {
      NumberStyle.global = NumberStyle.compact;
      final n = BigDouble(1.5, 3).withStyle(NumberStyle.scientific);

      expect(n.toString(), '1.5e3');
      expect('$n', '1.5e3');
    });

    test('the global style applies when nothing else is set', () {
      NumberStyle.global = NumberStyle.scientific;

      expect(BigDouble(1.5, 3).toString(), '1.5e3');

      NumberStyle.global = NumberStyle.compact;

      expect(BigDouble(1.5, 3).toString(), '1.5k');
    });

    test('interpolation goes through the same path', () {
      NumberStyle.global = NumberStyle.compact;

      expect('видобуто ${BigDouble(1.5, 3)} руди', 'видобуто 1.5k руди');
    });
  });

  group('style inheritance through arithmetic', () {
    setUp(() => NumberStyle.global = NumberStyle.compact);

    test('the left operand decides', () {
      final styled = BigDouble.fromNum(1000).withStyle(NumberStyle.scientific);
      final plain = BigDouble.fromNum(500);

      expect((styled + plain).toString(), '1.5e3');
      expect((plain + styled).toString(), '1.5k');
    });

    test('unary and single-operand results keep their style', () {
      final styled = BigDouble.fromNum(1000).withStyle(NumberStyle.scientific);

      expect((-styled).toString(), '-1e3');
      expect(styled.abs().toString(), '1e3');
      expect(styled.floor().toString(), '1e3');
      expect(styled.pow(2).toString(), '1e6');
    });

    test('min and max keep the style of the operand that wins', () {
      final styled = BigDouble.fromNum(1000).withStyle(NumberStyle.scientific);
      final plain = BigDouble.fromNum(2000);

      expect(styled.min(plain).toString(), '1e3');
      expect(styled.max(plain).toString(), '2k');
    });
  });

  group('style is not part of the value', () {
    test('equality ignores it', () {
      final a = BigDouble(1.5, 3).withStyle(NumberStyle.scientific);
      final b = BigDouble(1.5, 3).withStyle(NumberStyle.compact);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.compareTo(b), 0);
    });

    test('serialization ignores it', () {
      expect(BigDouble(1.5, 3).withStyle(NumberStyle.scientific).toJson(), '1.5e3');
    });
  });

  group('num extension', () {
    test('big converts without ceremony', () {
      expect(1500.big, BigDouble(1.5, 3));
      expect(0.25.big, BigDouble(2.5, -1));
    });
  });
}
