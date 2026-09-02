import 'dart:math' as math;

/// A scene's own smooth phase, servoed to the core's coarse one.
///
/// The rule every cycle animation obeys (the conveyor's lesson, applied
/// to the printer too): the scene runs its OWN phase frame by frame and
/// never extrapolates from a snapshot. The core settles once a second in
/// a lump, so its figure is STALE between settles; the servo therefore
/// corrects ONLY at the moment the core moves -- banking the wrap-aware
/// error and bleeding it out over the next [settleSeconds] -- and SNAPS
/// to the core after a hole in the frames ([gapSeconds]), a new job, or
/// a mount: the scene shows the current state and never replays what
/// nobody watched.
class PhaseServo {
  PhaseServo({this.settleSeconds = 0.5, this.gapSeconds = 0.25});

  /// How long a settle's error takes to bleed out.
  final double settleSeconds;

  /// A raw frame gap past this is a hole: snap, do not animate across it.
  final double gapSeconds;

  /// The scene's phase, 0..1.
  double phase = 0;

  double _coreSeen = double.nan;
  double _debt = 0;

  /// Lands on [core] outright and forgets any owed correction.
  void snap(double core) {
    phase = core;
    _coreSeen = core;
    _debt = 0;
  }

  /// Advances the phase by [dt] of a [unitSeconds] cycle and servos it
  /// toward [core]. Returns whether the phase wrapped past one this
  /// frame -- the beat a scene celebrates.
  bool advance({
    required double dt,
    required double raw,
    required double unitSeconds,
    required double core,
  }) {
    if (raw > gapSeconds || unitSeconds <= 0) {
      snap(core);
      return false;
    }
    var next = phase + dt / unitSeconds;
    if (core != _coreSeen) {
      _coreSeen = core;
      var error = core - (next % 1.0);
      if (error > 0.5) {
        error -= 1;
      } else if (error < -0.5) {
        error += 1;
      }
      _debt = error;
    }
    if (_debt.abs() > 1e-6) {
      final bleed = _debt * math.min(1, dt / settleSeconds);
      next += bleed;
      _debt -= bleed;
    }
    final wrapped = next >= 1;
    next %= 1.0;
    if (next < 0) next += 1;
    phase = next;
    return wrapped;
  }
}
