import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('why tolerance exists at all', () {
    test('accumulating a value drifts away from computing it directly', () {
      // Тисяча додавань по 0.001 дає 0.999999999999983, а не рівно одиницю.
      var accumulated = BigDouble.zero;
      for (var i = 0; i < 1000; i++) {
        accumulated = accumulated + BigDouble.fromNum(0.001);
      }

      expect(accumulated == BigDouble.one, isFalse,
          reason: 'інакше тест нічого не доводить');
      expect(accumulated.equalsWithTolerance(BigDouble.one), isTrue);
    });

    test('an affordability gate lets the player buy when the numbers match', () {
      // 15 — базова ціна бура. Ресурси прийшли шляхом, у якому було ділення
      // (так рахується офлайн-виробництво: темп × тіки × ефективність), і осіли
      // на один біт нижче. Строге >= сказало б гравцеві «не вистачає» при
      // візуально однакових числах.
      final cost = BigDouble.fromNum(15);
      final resources = cost / BigDouble.fromNum(9) * BigDouble.fromNum(9);

      expect(resources >= cost, isFalse, reason: 'інакше тест нічого не доводить');
      expect(resources.gteWithTolerance(cost), isTrue);
    });
  });

  group('equalsWithTolerance', () {
    test('accepts a difference inside the tolerance', () {
      expect(
        BigDouble(1.0000000000001, 5).equalsWithTolerance(BigDouble(1, 5)),
        isTrue,
      );
    });

    test('rejects a difference outside the tolerance', () {
      expect(BigDouble(1.001, 5).equalsWithTolerance(BigDouble(1, 5)), isFalse);
    });

    test('the tolerance is relative, not absolute', () {
      // Та сама відносна різниця має вирішуватись однаково на будь-якому масштабі.
      expect(
        BigDouble(1.0000000000001, 100).equalsWithTolerance(BigDouble(1, 100)),
        isTrue,
      );
      expect(
        BigDouble(1.0000000000001, -100).equalsWithTolerance(BigDouble(1, -100)),
        isTrue,
      );
    });

    test('accepts a custom tolerance', () {
      final a = BigDouble(1.05, 5);
      final b = BigDouble(1, 5);

      expect(a.equalsWithTolerance(b), isFalse);
      expect(a.equalsWithTolerance(b, 0.1), isTrue);
    });

    test('zero equals zero', () {
      expect(BigDouble.zero.equalsWithTolerance(BigDouble.zero), isTrue);
    });

    test('zero does not equal a real value', () {
      expect(BigDouble.zero.equalsWithTolerance(BigDouble(1, -50)), isFalse);
    });

    test('opposite signs are never within tolerance', () {
      expect(
        BigDouble(1, 5).equalsWithTolerance(BigDouble(-1, 5)),
        isFalse,
      );
    });
  });

  group('ordering with tolerance', () {
    test('gte accepts a value a hair below', () {
      expect(
        BigDouble(9.999999999999, 4).gteWithTolerance(BigDouble(1, 5)),
        isTrue,
      );
    });

    test('gte still rejects a genuinely smaller value', () {
      expect(BigDouble(9, 4).gteWithTolerance(BigDouble(1, 5)), isFalse);
    });

    test('lte accepts a value a hair above', () {
      expect(
        BigDouble(1.0000000000001, 5).lteWithTolerance(BigDouble(1, 5)),
        isTrue,
      );
    });

    test('compareWithTolerance reports equality as zero', () {
      expect(
        BigDouble(1.0000000000001, 5).compareWithTolerance(BigDouble(1, 5)),
        0,
      );
      expect(BigDouble(2, 5).compareWithTolerance(BigDouble(1, 5)), 1);
      expect(BigDouble(1, 5).compareWithTolerance(BigDouble(2, 5)), -1);
    });
  });

  group('default tolerance', () {
    test('is the value the genre settled on', () {
      expect(BigDouble.roundTolerance, 1e-10);
    });
  });
}
