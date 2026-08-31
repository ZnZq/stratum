import 'dart:math' as math;

import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'craft_recipe.dart';

/// One crafting line: a machine the player owns and retargets.
///
/// The upgrades (compression cap, speed) belong to the LINE; the recipe is
/// only what it currently makes, and the run mode is chosen together with
/// the recipe. State is signals, everything derived is in the graph.
class CraftLine {
  CraftLine(this._stock, int index) : _name = 'craft.$index' {
    speedFactor = Computed(
      () =>
          (1 + craftSpeedStep * speedLevel.value) *
          craftGameSpeed *
          (1 + craftBoostStep * boostStacks.value),
      name: '$_name.speed',
    );
    craftSeconds = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return 0;
      final raw =
          row.baseSeconds *
          math.pow(craftTimeStep, tier.value) /
          speedFactor.value;
      return raw < craftMinSeconds ? craftMinSeconds : raw;
    }, name: '$_name.seconds');
    unitsPerCraft = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return 0;
      return row.baseYield * math.pow(craftYieldStep, tier.value);
    }, name: '$_name.units');
    starving = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return false;
      // A loaded unit is already paid for: the line finishes it whatever
      // the stock says. Starving is failing to START the next one.
      if (unitLoaded.value) return false;
      final scale = math.pow(craftCostStep, tier.value).toDouble();
      for (final entry in row.inputs.entries) {
        final need = BigDouble.fromNum(entry.value * scale);
        if (!_stock.amount(entry.key).gteWithTolerance(need)) return true;
      }
      return false;
    }, name: '$_name.starving');
    // How long the line can keep going before something stops it: the
    // narrowest input, or the tail of a finite order -- whichever is
    // sooner. Floor pace on purpose (no warm-up), like every vitrine.
    // -1 means "no recipe, nothing to run out of".
    runwaySeconds = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return -1;
      final scale = math.pow(craftCostStep, tier.value).toDouble();
      var crafts = double.infinity;
      for (final entry in row.inputs.entries) {
        final k = _stock.amount(entry.key).toDouble() / (entry.value * scale);
        if (k < crafts) crafts = k;
      }
      if (unitLoaded.value) crafts += 1 - unitFraction.value;
      if (unitLoaded.value) crafts += 1 - unitFraction.value;
      if (unitLoaded.value) crafts += 1 - unitFraction.value;
      if (limit.value >= 0) {
        final left =
            (limit.value - producedCount.value) / unitsPerCraft.value;
        if (left < crafts) crafts = left < 0 ? 0 : left;
      }
      if (!crafts.isFinite) return -1;
      return crafts * craftSeconds.value;
    }, name: '$_name.runway');
    // The floor rate, like the mine's "X / s": the ramp AND the duplicate
    // chance are bonuses on top and deliberately not quoted -- the vitrine
    // shows the floor, and chance-borne extras land as pleasant surprises
    // (the same rule that keeps crit and echo out of the mine's figure).
    ratePerSecond = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null || done || halted.value || starving.value) {
        return BigDouble.zero;
      }
      final baseUnits = row.baseYield * math.pow(craftYieldStep, tier.value);
      return BigDouble.fromNum(baseUnits / craftSeconds.value);
    }, name: '$_name.rate');
  }

  final Stockpile _stock;
  final String _name;

  /// What the line makes; null is an owned machine waiting for work.
  late final Signal<ResourceId?> recipe = Signal(null, name: '$_name.recipe');

  /// The CHOSEN compression level, 0..[tierCap]. Locked while the line is
  /// running -- [PrototypeSimulation.setCraftTier] enforces it.
  late final Signal<int> tier = Signal(0, name: '$_name.tier');

  /// The PURCHASED compression ceiling of this line.
  late final Signal<int> tierCap = Signal(0, name: '$_name.tierCap');

  late final Signal<int> speedLevel = Signal(0, name: '$_name.speedLevel');

  /// The run mode chosen with the recipe: -1 crafts for ever, a positive
  /// number stops the line after that many output units.
  late final Signal<int> limit = Signal(-1, name: '$_name.limit');

  /// Output units delivered toward [limit] since the recipe was assigned.
  late final Signal<double> producedCount = Signal(0, name: '$_name.produced');

  /// A hand-stopped machine: the recipe is kept, nothing converts, and the
  /// compression level is free to change until the player resumes.
  late final Signal<bool> halted = Signal(false, name: '$_name.halted');

  /// The warm-up pile: whole stacks, each +1% speed, capped. Rolled per
  /// finished unit; reset whenever the job changes.
  late final Signal<int> boostStacks = Signal(0, name: '$_name.boost');

  /// How many whole units this JOB has finished -- the seed of both the
  /// boost and the duplicate rolls.
  late final Signal<int> unitOrdinal = Signal(0, name: '$_name.ordinal');

  /// How many of those units won the duplicate roll. Derived from the
  /// ordinal (the rolls are deterministic), kept incrementally because a
  /// recount per read would be quadratic over a long job; not saved --
  /// [readJson] recounts it once.
  late final Signal<int> dupCount = Signal(0, name: '$_name.dups');

  /// Whether the unit in progress has had its inputs taken. A unit is
  /// PREPAID: the full cost goes when it starts, and cancelling the job
  /// refunds it (owner's rule).
  late final Signal<bool> unitLoaded = Signal(false, name: '$_name.loaded');

  /// Seconds of starvation banked toward the next boost-stack decay:
  /// the remainder under [craftBoostDecaySeconds], carried so that one
  /// long hungry span equals the same span in pieces.
  late final Signal<double> starveBank = Signal(0, name: '$_name.starve');

  /// How far into the CURRENT unit the line is, 0..1 -- its own signal
  /// rather than a derivation of the produced count, because changing the
  /// recipe or the compression RESTARTS the unit (owner's rule) without
  /// touching what the order has already delivered.
  late final Signal<double> unitFraction = Signal(0, name: '$_name.unit');

  late final Computed<double> speedFactor;
  late final Computed<double> craftSeconds;
  late final Computed<double> unitsPerCraft;
  late final Computed<bool> starving;
  late final Computed<double> runwaySeconds;
  late final Computed<BigDouble> ratePerSecond;

  bool get running => recipe.value != null && !done && !halted.value;

  /// A finite order that has been filled: the line stands and says so.
  bool get done =>
      recipe.value != null &&
      limit.value >= 0 &&
      producedCount.value >= limit.value - 1e-9;

  /// The craft time as the line actually runs it right now; the boost is
  /// already inside [speedFactor], so this IS the effective figure.
  double get effectiveSeconds => craftSeconds.value;

  double get craftProgress => unitFraction.value;

  Map<String, Object?> toJson() => {
    if (recipe.value != null) 'r': recipe.value!.name,
    if (tier.value != 0) 't': tier.value,
    if (tierCap.value != 0) 'c': tierCap.value,
    if (speedLevel.value != 0) 's': speedLevel.value,
    if (limit.value != -1) 'n': limit.value,
    if (producedCount.value != 0) 'p': producedCount.value,
    if (halted.value) 'h': true,
    if (unitFraction.value != 0) 'u': unitFraction.value,
    if (unitLoaded.value) 'l': true,
    if (starveBank.value != 0) 'sb': starveBank.value,
    if (boostStacks.value != 0) 'b': boostStacks.value,
    if (unitOrdinal.value != 0) 'o': unitOrdinal.value,
  };

  void readJson(Object? raw) {
    final map = raw is Map ? raw : const <String, Object?>{};
    final recipeName = map['r'];
    ResourceId? found;
    if (recipeName is String) {
      for (final row in craftTable) {
        if (row.output.name == recipeName) found = row.output;
      }
    }
    // A recipe this build's table no longer knows melts to an empty line:
    // the balance moved, and that is never the player's debt.
    recipe.value = found;
    tierCap.value = _int(map['c']).clamp(0, craftTierCapMax);
    tier.value = _int(map['t']).clamp(0, tierCap.value);
    speedLevel.value = _int(map['s']);
    limit.value = map['n'] is num ? (map['n'] as num).toInt() : -1;
    producedCount.value = _double(map['p']);
    halted.value = map['h'] == true;
    unitLoaded.value = map['l'] == true;
    // An unpaid unit cannot be in progress: a save from the continuous
    // era carries a fraction without the prepaid flag, and it melts.
    unitFraction.value = unitLoaded.value
        ? _double(map['u']).clamp(0.0, 1.0)
        : 0.0;
    starveBank.value = _double(map['sb']);
    boostStacks.value = _int(map['b']).clamp(0, craftBoostCap);
    unitOrdinal.value = _int(map['o']);
    var dups = 0;
    for (var i = 0; i < unitOrdinal.value; i++) {
      if (craftDuplicateRoll(i)) dups++;
    }
    dupCount.value = dups;
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static double _double(Object? v) => v is num ? v.toDouble() : 0;
}
