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
      () => (1 + craftSpeedStep * speedLevel.value) * craftGameSpeed,
      name: '$_name.speed',
    );
    craftSeconds = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return 0;
      return row.baseSeconds *
          math.pow(craftTimeStep, tier.value) /
          speedFactor.value;
    }, name: '$_name.seconds');
    unitsPerCraft = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return 0;
      return row.baseYield *
          math.pow(craftYieldStep, tier.value) *
          (1 + craftDuplicateChance);
    }, name: '$_name.units');
    starving = Computed(() {
      final row = craftRecipeOf(recipe.value);
      if (row == null) return false;
      final scale = math.pow(craftCostStep, tier.value).toDouble();
      for (final entry in row.inputs.entries) {
        final need = BigDouble.fromNum(entry.value * scale);
        if (!_stock.amount(entry.key).gteWithTolerance(need)) return true;
      }
      return false;
    }, name: '$_name.starving');
    // The floor rate, like the mine's "X / s": the ramp is a bonus on top
    // and deliberately not quoted, so the figure never trembles.
    ratePerSecond = Computed(() {
      if (recipe.value == null || done || halted.value || starving.value) {
        return BigDouble.zero;
      }
      return BigDouble.fromNum(unitsPerCraft.value / craftSeconds.value);
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

  /// Continuous running time banked toward the ramp. Reset by starving and
  /// by standing idle, NOT by a recipe change.
  late final Signal<double> rampSeconds = Signal(0, name: '$_name.ramp');

  late final Computed<double> speedFactor;
  late final Computed<double> craftSeconds;
  late final Computed<double> unitsPerCraft;
  late final Computed<bool> starving;
  late final Computed<BigDouble> ratePerSecond;

  bool get running => recipe.value != null && !done && !halted.value;

  /// A finite order that has been filled: the line stands and says so.
  bool get done =>
      recipe.value != null &&
      limit.value >= 0 &&
      producedCount.value >= limit.value - 1e-9;

  double get rampProgress {
    final v = rampSeconds.value / craftRampFullSeconds;
    return v > 1 ? 1 : v;
  }

  /// The warm-up's current speed bonus, quoted by the effects strip.
  double get rampFactor => 1 + craftRampBonus * rampProgress;

  /// The craft time as the line actually runs it right now: the track and
  /// the warm-up together. Cheap arithmetic over cached values.
  double get effectiveSeconds => craftSeconds.value / rampFactor;

  /// How far into the CURRENT unit the line is, 0..1. The conversion is
  /// continuous, so the fraction of finished crafts IS the drum's angle.
  double get craftProgress {
    final units = unitsPerCraft.value;
    if (units <= 0) return 0;
    final crafts = producedCount.value / units;
    return crafts - crafts.floorToDouble();
  }

  Map<String, Object?> toJson() => {
    if (recipe.value != null) 'r': recipe.value!.name,
    if (tier.value != 0) 't': tier.value,
    if (tierCap.value != 0) 'c': tierCap.value,
    if (speedLevel.value != 0) 's': speedLevel.value,
    if (limit.value != -1) 'n': limit.value,
    if (producedCount.value != 0) 'p': producedCount.value,
    if (halted.value) 'h': true,
    if (rampSeconds.value != 0) 'w': rampSeconds.value,
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
    rampSeconds.value = _double(map['w']);
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static double _double(Object? v) => v is num ? v.toDouble() : 0;
}
