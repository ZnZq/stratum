import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_app/ui/phase_servo.dart';

/// The four rules of the phase loop, pinned: a scene runs its own phase,
/// corrects only when the core settles, snaps after a frame hole, and
/// never chases a stale figure.
void main() {
  test('the phase runs on its own between settles', () {
    final servo = PhaseServo()..snap(0);
    for (var i = 0; i < 10; i++) {
      servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 2, core: 0);
    }
    // A second of a two-second unit: halfway, whatever the stale core says.
    expect(servo.phase, closeTo(0.5, 1e-9));
  });

  test('a settle bleeds its error out instead of jumping', () {
    final servo = PhaseServo(settleSeconds: 0.5)..snap(0);
    servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 10, core: 0);
    // The core lands ahead of the scene: the error is banked, not applied.
    servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 10, core: 0.1);
    expect(servo.phase, lessThan(0.1));
    expect(servo.phase, greaterThan(0.02));
    for (var i = 0; i < 20; i++) {
      servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 10, core: 0.1);
    }
    // Two seconds later the free run has covered 0.22 of the unit and the
    // 0.08 error is paid down geometrically -- all but a residual under
    // a thousandth, which is the servo's smoothness, not a miss.
    expect(servo.phase, closeTo(0.30, 1e-3));
  });

  test('the correction takes the short way round the wrap', () {
    final servo = PhaseServo(settleSeconds: 0.1)..snap(0.98);
    for (var i = 0; i < 5; i++) {
      servo.advance(dt: 0.05, raw: 0.05, unitSeconds: 100, core: 0.02);
    }
    // 0.98 -> 0.02 is four hundredths forward, never ninety-six back: the
    // phase lands just past 0.02, not somewhere in the nineties.
    expect(servo.phase, closeTo(0.0225, 3e-3));
    expect(servo.phase, lessThan(0.05));
  });

  test('a frame hole snaps to the core and drops the debt', () {
    final servo = PhaseServo()..snap(0.2);
    servo.advance(dt: 0.05, raw: 0.05, unitSeconds: 1, core: 0.7);
    final wrapped = servo.advance(dt: 0.066, raw: 3, unitSeconds: 1, core: 0.4);
    expect(servo.phase, 0.4);
    expect(wrapped, isFalse);
  });

  test('the wrap past one is reported once', () {
    final servo = PhaseServo()..snap(0.95);
    expect(
      servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 1, core: 0.95),
      isTrue,
    );
    expect(servo.phase, closeTo(0.05, 1e-9));
    expect(
      servo.advance(dt: 0.1, raw: 0.1, unitSeconds: 1, core: 0.95),
      isFalse,
    );
  });
}
