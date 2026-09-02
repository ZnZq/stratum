import 'dart:math' as math;

import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'craft_recipe.dart';
import 'trade_groups.dart';

/// The replicator runs in CYCLES: one cycle is the resource's own base
/// craft time stretched by its tier, and each finished cycle pays the
/// tier's yield. PROVISIONAL by rule zero.
const double replicatorMinSeconds = 1;

/// Each speed level shaves one percent off the CURRENT cycle time (0.99^n
/// -- the drill-drive reading: geometric, never crossing zero), still
/// floored at one second.
const double replicatorSpeedDecay = 0.99;

/// What the replicator may copy: only what a bench can MAKE -- the craft
/// outputs. Raw diggings, currencies and prestige fuel never replicate
/// (owner, 2026-09-01).
final List<ResourceId> replicableIds = [
  for (final row in craftTable) row.output,
];

/// One number per tier -- the shape every replicator table shares.
double _tierOf(ResourceId id, double materials, double building, double tech) =>
    switch (tierKeyOf(id)) {
      'building' => building,
      'tech' => tech,
      _ => materials,
    };

/// What one cycle pays before the amount track, by tier.
int replicatorBaseYield(ResourceId id) => _tierOf(id, 100, 50, 5).round();

/// The cycle stretches the craft time by tier (owner, 2026-09-01):
/// materials x2, building x4, technologies x8.
double replicatorDurationFactor(ResourceId id) => _tierOf(id, 2, 4, 8);

/// What one amount level ADDS to the payout, by tier.
int replicatorAmountStep(ResourceId id) => _tierOf(id, 10, 5, 1).round();

/// The one-time toll for calibrating a machine to a resource, paid in
/// units of THAT resource and priced by its tier (owner, 2026-09-01).
double replicatorUnlockCost(ResourceId id) => _tierOf(id, 5000, 2500, 750);

/// Quantonium's first use since its restart-currency role was cut (owner,
/// 2026-09-01): every replicator payment point also costs the mineral.
/// Calibration is flat by tier; the tracks double per level off a share
/// of it.
double replicatorUnlockQuant(ResourceId id) => _tierOf(id, 2500, 5000, 10000);

/// The cycle at any speed level -- the one formula the machine runs on and
/// its buttons preview with.
double replicatorSecondsAt(ResourceId id, int speedLevel) {
  final base = craftRecipeOf(id)!.baseSeconds * replicatorDurationFactor(id);
  final paced = base * math.pow(replicatorSpeedDecay, speedLevel);
  return paced < replicatorMinSeconds ? replicatorMinSeconds : paced;
}

/// One replicator: the machine calibrated to [id], its two tracks, and
/// the fraction of the cycle it stands in. State is signals, everything
/// derived is in the graph -- the same shape as [CraftLine].
///
/// Calibration and both tracks survive every prestige (owner,
/// 2026-09-01); the fraction is the run's working state.
class ReplicatorMachine {
  ReplicatorMachine(this._stock, this.id) {
    final name = 'replicator ${id.name}';
    unlocked = Signal(false, name: '$name open');
    speed = Signal(0, name: '$name speed');
    amount = Signal(0, name: '$name amount');
    fraction = Signal(0, name: '$name cycle');
    seconds = Computed(
      () => replicatorSecondsAt(id, speed.value),
      name: '$name seconds',
    );
    yieldPerCycle = Computed(
      () => replicatorBaseYield(id) + replicatorAmountStep(id) * amount.value,
      name: '$name yield',
    );
    // The vitrine's floor: the payout spread over the cycle, per second.
    perSecond = Computed(
      () => BigDouble.fromNum(yieldPerCycle.value / seconds.value),
      name: '$name per second',
    );
    // Both tracks price in the resource itself, geometrically off the
    // tier's toll; their quantonium asks are a share of the calibration
    // ask, doubling per level. PROVISIONAL by rule zero.
    speedCost = Computed(
      () =>
          BigDouble.fromNum(replicatorUnlockCost(id)) *
          BigDouble.fromNum(3).pow(speed.value + 1.0),
      name: '$name speed cost',
    );
    amountCost = Computed(
      () =>
          BigDouble.fromNum(replicatorUnlockCost(id)) *
          BigDouble.fromNum(4).pow(amount.value + 1.0),
      name: '$name amount cost',
    );
    speedQuant = Computed(
      () =>
          BigDouble.fromNum(replicatorUnlockQuant(id) * 0.1) *
          BigDouble.fromNum(2).pow(speed.value.toDouble()),
      name: '$name speed quant',
    );
    amountQuant = Computed(
      () =>
          BigDouble.fromNum(replicatorUnlockQuant(id) * 0.15) *
          BigDouble.fromNum(2).pow(amount.value.toDouble()),
      name: '$name amount quant',
    );
  }

  final Stockpile _stock;
  final ResourceId id;

  late final Signal<bool> unlocked;
  late final Signal<int> speed;
  late final Signal<int> amount;

  /// How far into its current cycle the machine stands, 0..1.
  late final Signal<double> fraction;

  late final Computed<double> seconds;
  late final Computed<int> yieldPerCycle;
  late final Computed<BigDouble> perSecond;
  late final Computed<BigDouble> speedCost;
  late final Computed<BigDouble> amountCost;
  late final Computed<BigDouble> speedQuant;
  late final Computed<BigDouble> amountQuant;

  BigDouble get _unlockCost => BigDouble.fromNum(replicatorUnlockCost(id));
  BigDouble get _unlockQuant => BigDouble.fromNum(replicatorUnlockQuant(id));

  bool get canUnlock =>
      !unlocked.value &&
      _stock.has(id, _unlockCost) &&
      _stock.has(ResourceId.quantonium, _unlockQuant);

  /// Pays the toll -- the resource itself plus quantonium -- and opens
  /// the machine. Both are checked before either is spent.
  bool unlock() {
    if (!canUnlock) return false;
    _stock.spend(id, _unlockCost);
    _stock.spend(ResourceId.quantonium, _unlockQuant);
    unlocked.value = true;
    return true;
  }

  bool get canSpeedUp =>
      unlocked.value &&
      _stock.has(id, speedCost.value) &&
      _stock.has(ResourceId.quantonium, speedQuant.value);

  bool get canWiden =>
      unlocked.value &&
      _stock.has(id, amountCost.value) &&
      _stock.has(ResourceId.quantonium, amountQuant.value);

  bool speedUp() {
    if (!canSpeedUp) return false;
    _stock.spend(id, speedCost.value);
    _stock.spend(ResourceId.quantonium, speedQuant.value);
    speed.value = speed.value + 1;
    return true;
  }

  bool widen() {
    if (!canWiden) return false;
    _stock.spend(id, amountCost.value);
    _stock.spend(ResourceId.quantonium, amountQuant.value);
    amount.value = amount.value + 1;
    return true;
  }

  /// Walks [span] seconds of cycles, banking the unfinished fraction --
  /// so one long span equals the same span in pieces -- and returns what
  /// the whole cycles paid. Payouts land in whole cycles only, like the
  /// bench's prepaid units.
  BigDouble run(double span) {
    if (!unlocked.value) return BigDouble.zero;
    final total = fraction.value + span / seconds.value;
    final whole = total.floor();
    fraction.value = total - whole;
    if (whole <= 0) return BigDouble.zero;
    final gained = BigDouble.fromNum(whole * yieldPerCycle.value.toDouble());
    _stock.add(id, gained);
    return gained;
  }

  /// Only departures from a fresh machine, under the flat keys the save
  /// has always used; calibration itself is listed by the owner of the
  /// section.
  Map<String, Object?> toJson() => {
    if (speed.value != 0) 'sp.${id.name}': speed.value,
    if (amount.value != 0) 'am.${id.name}': amount.value,
    if (fraction.value != 0) 'fr.${id.name}': fraction.value,
  };

  void readJson(Map<Object?, Object?> json, {required bool unlocked}) {
    this.unlocked.value = unlocked;
    speed.value = _int(json['sp.${id.name}']);
    amount.value = _int(json['am.${id.name}']);
    fraction.value = _double(json['fr.${id.name}']).clamp(0.0, 1.0);
  }

  void reset() {
    unlocked.value = false;
    speed.value = 0;
    amount.value = 0;
    fraction.value = 0;
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static double _double(Object? v) => v is num ? v.toDouble() : 0;
}
