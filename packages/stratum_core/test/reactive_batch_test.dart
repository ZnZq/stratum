import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('coalescing notifications', () {
    test('many writes to one signal notify once', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 3;
      });

      expect(notifications, 1);
    });

    test('writes to several signals notify each listener once', () {
      final a = Signal(0);
      final b = Signal(0);
      var notifiedA = 0;
      var notifiedB = 0;
      a.listen(() => notifiedA++);
      b.listen(() => notifiedB++);

      batch(() {
        a.value = 1;
        b.value = 1;
        a.value = 2;
      });

      expect(notifiedA, 1);
      expect(notifiedB, 1);
    });

    test('a computed downstream notifies once for a whole batch', () {
      final a = Signal(1);
      final b = Signal(1);
      final sum = Computed(() => a.value + b.value);
      var notifications = 0;
      sum.listen(() => notifications++);

      batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(notifications, 1);
      expect(sum.value, 30);
    });

    test('without a batch the same writes notify separately', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      s.value = 1;
      s.value = 2;

      expect(
        notifications,
        2,
        reason: 'otherwise this test does not prove batch does anything',
      );
    });
  });

  group('reads stay fresh inside a batch', () {
    test('a signal read right after a write gives the new value', () {
      final s = Signal(1);

      batch(() {
        s.value = 2;
        expect(s.value, 2);
      });
    });

    test('a computed read inside a batch reflects writes already made', () {
      // Exactly what a tick loop does: write, then read derived values.
      final drills = Signal(0);
      final power = Computed(() => 10 + 6 * drills.value);

      batch(() {
        expect(power.value, 10);
        drills.value = 5;
        expect(power.value, 40);
        drills.value = 10;
        expect(power.value, 70);
      });

      expect(power.value, 70);
    });
  });

  group('nesting', () {
    test('only the outermost batch flushes', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      batch(() {
        s.value = 1;
        batch(() {
          s.value = 2;
        });
        expect(notifications, 0, reason: 'a nested batch must not flush');
        s.value = 3;
      });

      expect(notifications, 1);
    });
  });

  group('return value', () {
    test('passes the body result through', () {
      final s = Signal(2);

      final doubled = batch(() {
        s.value = 21;
        return s.value * 2;
      });

      expect(doubled, 42);
    });

    test('a void body is fine', () {
      final s = Signal(0);

      expect(() => batch(() => s.value = 1), returnsNormally);
      expect(s.value, 1);
    });
  });

  group('exceptions', () {
    test('a throwing body still flushes what was already written', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      expect(
        () => batch(() {
          s.value = 1;
          throw StateError('on purpose');
        }),
        throwsStateError,
      );

      expect(
        s.value,
        1,
        reason: 'the write already happened and is not rolled back',
      );
      expect(
        notifications,
        1,
        reason: 'the listener must learn about a real change',
      );
    });

    test('a throw does not leave the batch depth stuck', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      expect(
        () => batch(() => throw StateError('on purpose')),
        throwsStateError,
      );

      // Had the depth stayed non-zero, notifications would go silent forever.
      s.value = 1;

      expect(notifications, 1);
    });
  });

  group('edges', () {
    test('an empty batch notifies nobody', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      batch(() {});

      expect(notifications, 0);
    });

    test('a batch with no writes notifies nobody', () {
      final s = Signal(0);
      var notifications = 0;
      s.listen(() => notifications++);

      batch(() => s.value);

      expect(notifications, 0);
    });

    test('writing an equal value inside a batch still notifies nobody', () {
      final s = Signal(7);
      var notifications = 0;
      s.listen(() => notifications++);

      batch(() {
        s.value = 7;
        s.value = 7;
      });

      expect(notifications, 0);
    });

    test('a node disposed inside a batch is not notified at flush', () {
      final s = Signal(0);
      final c = Computed(() => s.value * 2);
      var notifications = 0;
      c.listen(() => notifications++);

      batch(() {
        s.value = 1;
        c.dispose();
      });

      expect(notifications, 0);
    });
  });
}
