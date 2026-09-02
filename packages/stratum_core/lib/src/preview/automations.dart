import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';

/// The rungs of the automation ladder: what runs on the player's
/// behalf. The hands and the rig are NOT here (owner, 2026-09-02): the
/// hands are the player, the rig is a purchase on the drills screen --
/// automation is what does, unasked, what the player could do.
enum AutomationId {
  /// Strikes without a finger, on an interval, at the price of slower
  /// energy regen while it runs.
  autoHands,

  /// Sells chosen positions on their own intervals, above a kept floor.
  autoSell,

  /// Fulfils requests that respect the player's protected resources and
  /// the share of a pile a request may take.
  autoRequests,

  /// Buys the chosen upgrade tracks on an interval, so many per cycle.
  autoBuy,

  /// Points idle benches at the most valuable recipe they can feed.
  autoCraft,
}

/// The presets every interval picker offers, in seconds. PROVISIONAL.
const List<double> automationIntervals = [10, 30, 60, 300];

/// What the player has automated so far. A fresh run has NOTHING
/// (owner, 2026-09-02).
///
/// Unlocks are one-shot and, once the prestige acts exist, survive a
/// Restart: the manual phase is played exactly once.
class Automations {
  Automations(this._stock);

  final Stockpile _stock;

  final Map<AutomationId, Signal<bool>> _unlocked = {
    for (final id in AutomationId.values)
      id: Signal(false, name: 'automation ${id.name}'),
  };

  Signal<bool> unlockedOf(AutomationId id) => _unlocked[id]!;

  bool has(AutomationId id) => _unlocked[id]!.value;

  /// What a rung costs, in credits; null is a rung not for sale yet.
  /// PROVISIONAL by rule zero.
  static BigDouble? costOf(AutomationId id) => switch (id) {
    AutomationId.autoHands => BigDouble.fromNum(500),
    AutomationId.autoSell => BigDouble.fromNum(300),
    AutomationId.autoRequests => BigDouble.fromNum(800),
    AutomationId.autoBuy => BigDouble.fromNum(1500),
    AutomationId.autoCraft => BigDouble.fromNum(5000),
  };

  bool canUnlock(AutomationId id) {
    final cost = costOf(id);
    return !has(id) && cost != null && _stock.has(ResourceId.credits, cost);
  }

  /// Pays for [id] and switches it on. Refused when it is already on,
  /// not for sale, or unaffordable -- nothing is spent then.
  bool unlock(AutomationId id) {
    if (!canUnlock(id)) return false;
    _stock.spend(ResourceId.credits, costOf(id)!);
    _unlocked[id]!.value = true;
    return true;
  }

  /// Switches [id] on for free: a save from before the ladder existed,
  /// or a future Restart's opening cascade.
  void grant(AutomationId id) => _unlocked[id]!.value = true;

  /// Only what is on: a fresh run writes nothing here.
  Map<String, Object?> toJson() => {
    if (_unlocked.values.any((signal) => signal.value))
      'u': [
        for (final entry in _unlocked.entries)
          if (entry.value.value) entry.key.name,
      ],
  };

  void readJson(Object? json) {
    final opened = json is Map ? json['u'] : null;
    for (final entry in _unlocked.entries) {
      entry.value.value = opened is List && opened.contains(entry.key.name);
    }
  }
}
