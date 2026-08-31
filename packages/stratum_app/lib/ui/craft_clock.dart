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
