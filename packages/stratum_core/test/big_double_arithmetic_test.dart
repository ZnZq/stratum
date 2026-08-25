import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Перевіряє інваріант нормалізації: або точний нуль, або мантиса в [1, 10).
void expectNormalized(BigDouble n, String what) {
  if (n.isZero) {
    expect(n.mantissa, 0.0, reason: '$what: нуль має канонічну мантису');
    expect(n.exponent, 0, reason: '$what: нуль має канонічну експоненту');
    return;
  }
  expect(n.mantissa.abs(), greaterThanOrEqualTo(1.0), reason: '$what: мантиса < 1');
  expect(n.mantissa.abs(), lessThan(10.0), reason: '$what: мантиса >= 10');
}

void main() {
  group('addition', () {
    test('adds numbers sharing an exponent', () {
      expect(BigDouble(2, 5) + BigDouble(3, 5), BigDouble(5, 5));
    });

    test('adds numbers with different exponents', () {
      expect(BigDouble(1, 5) + BigDouble(1, 2), BigDouble(1.001, 5));
    });

    test('renormalizes when the sum carries over', () {
      expect(BigDouble(6, 5) + BigDouble(7, 5), BigDouble(1.3, 6));
    });

    test('adding zero is identity', () {
      expect(BigDouble(4.2, 9) + BigDouble.zero, BigDouble(4.2, 9));
      expect(BigDouble.zero + BigDouble(4.2, 9), BigDouble(4.2, 9));
    });

    test('adding opposites gives canonical zero', () {
      expect(BigDouble(4.2, 9) + BigDouble(-4.2, 9), BigDouble.zero);
    });

    test('a magnitude far below the other leaves it unchanged', () {
      // У арифметиці з ~17 значущими цифрами 1e50 + 1e10 дорівнює 1e50.
      expect(BigDouble(1, 50) + BigDouble(1, 10), BigDouble(1, 50));
      expect(BigDouble(1, 10) + BigDouble(1, 50), BigDouble(1, 50));
    });

    test('a far-below negative also leaves the larger unchanged', () {
      expect(BigDouble(1, 50) + BigDouble(-1, 10), BigDouble(1, 50));
    });
  });

  group('subtraction', () {
    test('subtracts numbers sharing an exponent', () {
      expect(BigDouble(5, 5) - BigDouble(3, 5), BigDouble(2, 5));
    });

    test('crosses zero into negative', () {
      expect(BigDouble(3, 5) - BigDouble(5, 5), BigDouble(-2, 5));
    });

    test('subtracting itself gives canonical zero', () {
      expect(BigDouble(7.3, 12) - BigDouble(7.3, 12), BigDouble.zero);
    });
  });

  group('multiplication', () {
    test('adds exponents and multiplies mantissas', () {
      expect(BigDouble(2, 5) * BigDouble(3, 7), BigDouble(6, 12));
    });

    test('renormalizes when the product carries over', () {
      expect(BigDouble(5, 5) * BigDouble(5, 5), BigDouble(2.5, 11));
    });

    test('multiplying by zero gives canonical zero', () {
      expect(BigDouble(9, 300) * BigDouble.zero, BigDouble.zero);
    });

    test('signs multiply', () {
      expect(BigDouble(-2, 5) * BigDouble(3, 7), BigDouble(-6, 12));
      expect(BigDouble(-2, 5) * BigDouble(-3, 7), BigDouble(6, 12));
    });
  });

  group('division', () {
    test('subtracts exponents and divides mantissas', () {
      expect(BigDouble(6, 12) / BigDouble(3, 7), BigDouble(2, 5));
    });

    test('renormalizes when the quotient borrows', () {
      expect(BigDouble(2, 11) / BigDouble(5, 5), BigDouble(4, 5));
    });

    test('zero divided by anything is canonical zero', () {
      expect(BigDouble.zero / BigDouble(3, 7), BigDouble.zero);
    });

    test('dividing by one is identity', () {
      expect(BigDouble(4.2, 9) / BigDouble.one, BigDouble(4.2, 9));
    });
  });

  group('reciprocal', () {
    test('inverts a value', () {
      expect(BigDouble(4, 2).reciprocal(), BigDouble(2.5, -3));
    });
  });

  group('double oracle', () {
    // Там, де звичайний double ще не ламається, BigDouble зобов'язаний давати
    // той самий результат. Це ловить помилки нормалізації й переносу експоненти
    // щільніше, ніж приклади, написані руками.
    test('matches plain double arithmetic across random pairs', () {
      final rng = math.Random(20260825);

      for (var i = 0; i < 2000; i++) {
        final a = (rng.nextDouble() * 2 - 1) * math.pow(10, rng.nextInt(60) - 30);
        final b = (rng.nextDouble() * 2 - 1) * math.pow(10, rng.nextInt(60) - 30);
        if (a == 0 || b == 0) continue;

        final ba = BigDouble.fromNum(a);
        final bb = BigDouble.fromNum(b);

        for (final (label, got, want) in <(String, BigDouble, double)>[
          ('$a + $b', ba + bb, a + b),
          ('$a - $b', ba - bb, a - b),
          ('$a * $b', ba * bb, a * b),
          ('$a / $b', ba / bb, a / b),
        ]) {
          expectNormalized(got, label);
          final relative = (got.toDouble() - want).abs() / want.abs();
          expect(relative, lessThan(1e-12), reason: 'розбіжність на $label');
        }
      }
    });
  });
}
