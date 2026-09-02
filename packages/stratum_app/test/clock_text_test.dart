import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_app/ui/clock_text.dart';

void main() {
  test('craftClock skips zero parts and never prints 0h', () {
    expect(craftClock(0), '0s');
    expect(craftClock(45), '45s');
    expect(craftClock(120), '2m');
    expect(craftClock(87), '1m 27s');
    expect(craftClock(3605), '1h 5s');
  });

  test('shortClock squeezes into a dial', () {
    expect(shortClock(43), '43s');
    expect(shortClock(87), '1:27');
    expect(shortClock(3660), '61m');
  });

  test('mmssClock and hmsClock count down and stop at zero', () {
    expect(mmssClock(425000), '7:05');
    expect(mmssClock(0), '0:00');
    expect(mmssClock(-5), '0:00');
    expect(hmsClock(4025000), '1:07:05');
    expect(hmsClock(0), '0:00:00');
  });

  test('simClock shows days only once there is one', () {
    expect(simClock(65), '0:01:05');
    expect(simClock(90061), '1д 1:01:01');
  });
}
