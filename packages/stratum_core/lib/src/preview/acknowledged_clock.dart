/// The clock every wall-time mechanic runs on: real time, acknowledged in
/// gaps that are each clamped to the absence cap. Away for a week, paid
/// and drifted as if away for two days -- one constant, one clock, so no
/// two mechanics can quietly disagree about how long the player was gone.
class AcknowledgedClock {
  /// The longest absence the game acknowledges in one gap.
  static const int absenceCapMs = 48 * 60 * 60 * 1000;

  /// Wall time the game has acknowledged, in ms. Advances by real gaps,
  /// each clamped to [absenceCapMs].
  int seenMs = 0;

  /// The raw wall stamp of the last [observe]. Zero = never observed; the
  /// first observation banks nothing, so the epoch offset never leaks into
  /// the acknowledged total.
  int lastWallMs = 0;

  /// Where THIS simulation began on the acknowledged clock, so the time
  /// spent IN it counts capped absences the way everything else does. A
  /// future Restart resets it along with the run.
  int runStartMs = 0;

  /// What the clock reads at [nowMs], WITHOUT banking it. Continuous
  /// between observations; a gap longer than the cap contributes exactly
  /// the cap, and a clock wound backwards contributes nothing.
  int seenNow(int nowMs) {
    if (lastWallMs == 0) return seenMs;
    final gap = nowMs - lastWallMs;
    if (gap <= 0) return seenMs;
    return seenMs + (gap > absenceCapMs ? absenceCapMs : gap);
  }

  /// Banks the clock up to [nowMs]. The app calls this every batch and on
  /// every return from absence; between calls [seenNow] extrapolates.
  ///
  /// MONOTONIC: a rewound wall clock banks nothing and, crucially, does
  /// not move [lastWallMs] backwards -- that stamp is the breach
  /// detector's evidence, and letting a rewound clock overwrite it would
  /// pardon the very tampering it proves.
  void observe(int nowMs) {
    if (nowMs <= lastWallMs) return;
    seenMs = seenNow(nowMs);
    lastWallMs = nowMs;
  }

  /// Seconds lived inside this simulation, on the acknowledged clock.
  double simSeconds(int nowMs) => (seenNow(nowMs) - runStartMs) / 1000.0;

  Map<String, Object?> toJson() => {'seen': seenMs, 'last': lastWallMs};

  void readJson(Object? json) {
    if (json is! Map) {
      seenMs = 0;
      lastWallMs = 0;
      return;
    }
    seenMs = _int(json['seen']);
    lastWallMs = _int(json['last']);
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
