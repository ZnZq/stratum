import '../reactive_graph.dart';

/// Auto-hands: a strike thrown every [intervalSeconds] without a finger.
/// The price of not pressing is a slower gauge: while it runs, energy
/// regenerates [regenSlowdown] times slower, and the faster the hands,
/// the steeper the penalty -- the setting is a trade, not a free lunch.
/// ONLINE ONLY (owner, 2026-09-02): an absence throws no strikes, and the
/// hand lane's offline expectation already stands in for them.
class AutoStrike {
  AutoStrike() {
    regenSlowdown = Computed(
      () => enabled.value ? 1 + slowdownPerHertz / intervalSeconds.value : 1.0,
      name: 'auto strike slowdown',
    );
  }

  /// The intervals the picker offers, in seconds. PROVISIONAL.
  static const List<double> intervals = [1, 2, 4, 8];

  /// How much regen slows per strike-per-second: at one strike a second
  /// the gauge fills three times slower, at one every four seconds one
  /// and a half times. PROVISIONAL by rule zero.
  static const double slowdownPerHertz = 2;

  /// Whether the hands are swinging. Off keeps the setting and lifts the
  /// penalty.
  final Signal<bool> enabled = Signal(true, name: 'auto strike on');

  final Signal<double> intervalSeconds = Signal(
    2,
    name: 'auto strike interval',
  );

  /// The factor the regen wait is multiplied by while the hands run.
  late final Computed<double> regenSlowdown;

  double _bank = 0;

  /// How many strikes fell due over [span] seconds, the remainder banked
  /// so one long span equals the same span in pieces. Capped: a stall of
  /// the app must not come back as a burst of a hundred blows.
  int due(double span) {
    if (!enabled.value || span <= 0) return 0;
    _bank += span / intervalSeconds.value;
    var count = _bank.floor();
    if (count > maxBurst) count = maxBurst;
    _bank -= count;
    if (_bank > 1) _bank = 0;
    return count;
  }

  static const int maxBurst = 10;

  /// Forgets any strikes owed: on a return from absence the hands start
  /// fresh rather than replaying what nobody was there for.
  void restamp() => _bank = 0;

  Map<String, Object?> toJson() => {
    if (!enabled.value) 'off': true,
    if (intervalSeconds.value != 2) 'iv': intervalSeconds.value,
  };

  void readJson(Object? json) {
    enabled.value = !(json is Map && json['off'] == true);
    final iv = json is Map ? json['iv'] : null;
    intervalSeconds.value = iv is num && iv > 0 ? iv.toDouble() : 2;
    _bank = 0;
  }
}
