/// The three tracks every drill carries.
enum DrillPart {
  /// How wide a face the bore covers. Additive on the radius, quadratic on
  /// the area -- the same level is worth more the wider the bore already is.
  radius,

  /// How often it cycles. Multiplicative on the interval, so the track is
  /// finite: it ends where the interval meets the floor.
  drive,

  /// How lucky it is: the odds of a crit and of an echo, bought together.
  calibration,
}
