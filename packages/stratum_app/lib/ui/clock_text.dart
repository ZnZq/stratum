// Every clock the interface prints, in one place: five screens used to
// carry a formatter each, two of them byte for byte the same.

/// A craft duration, zero parts skipped: `1m 27s`, `45s`, `2m`, `1h 5s` --
/// never `0h 1m 27s` (owner's rule).
String craftClock(double seconds) {
  final whole = seconds.round();
  final h = whole ~/ 3600;
  final m = (whole % 3600) ~/ 60;
  final s = whole % 60;
  final parts = [if (h > 0) '${h}h', if (m > 0) '${m}m', if (s > 0) '${s}s'];
  return parts.isEmpty ? '0s' : parts.join(' ');
}

/// A countdown squeezed into a small dial: `43s`, `1:27`, `61m`.
String shortClock(double seconds) {
  final whole = seconds.ceil();
  if (whole < 60) return '${whole}s';
  if (whole < 3600) return '${whole ~/ 60}:${_two(whole % 60)}';
  return '${whole ~/ 60}m';
}

/// Minutes and seconds left of [ms]: `7:05`, `0:00` once it is gone.
String mmssClock(int ms) {
  if (ms <= 0) return '0:00';
  final seconds = (ms / 1000).ceil();
  return '${seconds ~/ 60}:${_two(seconds % 60)}';
}

/// Hours, minutes and seconds left of [ms]: `1:07:05`, `0:00:00` when gone.
String hmsClock(int ms) {
  if (ms <= 0) return '0:00:00';
  final s = (ms / 1000).ceil();
  return '${s ~/ 3600}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

/// A simulation's internal age, precise to the second: a day count when
/// there is one, then a running h:mm:ss clock.
String simClock(double seconds) {
  final whole = seconds.floor();
  final d = whole ~/ 86400;
  final h = (whole % 86400) ~/ 3600;
  final m = (whole % 3600) ~/ 60;
  final sec = whole % 60;
  final clock = '$h:${_two(m)}:${_two(sec)}';
  return d > 0 ? '$dд $clock' : clock;
}

/// An automation interval as a picker prints it: `10 с`, `1 хв`, `5 хв`.
String intervalText(double seconds) {
  if (seconds < 60) {
    final whole = seconds == seconds.roundToDouble()
        ? '${seconds.round()}'
        : seconds.toStringAsFixed(1);
    return '$whole с';
  }
  final minutes = seconds / 60;
  final whole = minutes == minutes.roundToDouble()
      ? '${minutes.round()}'
      : minutes.toStringAsFixed(1);
  return '$whole хв';
}

String _two(int v) => v.toString().padLeft(2, '0');
