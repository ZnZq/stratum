import '../big_double.dart';
import '../random_source.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';

/// What one drilling cycle produced, for the UI to turn into feedback.
class CycleOutcome {
  const CycleOutcome({
    required this.oreGained,
    required this.crystalsGained,
    required this.quantoniumGained,
    required this.critical,
    required this.layersBroken,
    required this.thickLayersBroken,
    required this.echoes,
  });

  static const CycleOutcome none = CycleOutcome(
    oreGained: BigDouble.zero,
    crystalsGained: BigDouble.zero,
    quantoniumGained: 0,
    critical: false,
    layersBroken: 0,
    thickLayersBroken: 0,
    echoes: 0,
  );

  final BigDouble oreGained;
  final BigDouble crystalsGained;
  final int quantoniumGained;
  final bool critical;
  final int layersBroken;
  final int thickLayersBroken;
  final int echoes;
}

/// A provisional model of the drilling loop, carrying the prototype's numbers.
///
/// PROVISIONAL. The balance reference is still undecided — the prototype's
/// plain exponent versus the accelerating exponent from the research report —
/// so the constants here are the prototype's and are expected to move. The
/// shape of the loop is what this is for: something the UI can render and the
/// balance harness can measure before that decision lands.
///
/// Every derived quantity is a [Computed], so the UI reads them freely without
/// recomputing anything that has not changed.
class PrototypeSimulation {
  PrototypeSimulation({int seed = 20260825})
    : random = RandomSource(seed: seed) {
    layerDensity = Computed(
      () => densityAt(layer.value),
      name: 'layer density',
    );
    perDrillPower = Computed(
      () => perDrillPowerWith(drillPowerLevel.value),
      name: 'power per drill',
    );
    power = Computed(
      () => powerWith(drills: drills.value, upgrades: drillPowerLevel.value),
      name: 'drill power',
    );
    powerUpgradeCost = Computed(
      () =>
          (BigDouble.fromNum(50) *
                  BigDouble.fromNum(1.75).pow(drillPowerLevel.value.toDouble()))
              .ceil(),
      name: 'power upgrade cost',
    );
    orePerCycle = Computed(
      () =>
          BigDouble.fromNum(1.6) *
          BigDouble.fromNum(1.03).pow(layer.value.toDouble()) *
          BigDouble.fromNum(1.2).pow(enrichmentLevel.value.toDouble()),
      name: 'ore per cycle',
    );
    drillCost = Computed(
      () =>
          (BigDouble.fromNum(15) *
                  BigDouble.fromNum(1.13).pow(drills.value.toDouble()) *
                  BigDouble.fromNum(1 - 0.04 * discountLevel.value))
              .ceil(),
      name: 'drill cost',
    );
    cyclesToBreak = Computed(() {
      final remaining = layerHp.value;
      final perCycle = power.value;
      if (perCycle.isZero) return 1;
      final estimate = (remaining / perCycle).ceil().toDouble();
      return estimate < 1 ? 1 : estimate.toInt();
    }, name: 'cycles to break');

    _resetLayer();
  }

  /// Not final: restoring a save swaps in the streams as they stood, so the
  /// rolls carry on from where the player left them rather than replaying the
  /// same sequence from the seed every launch.
  RandomSource random;

  final Signal<int> layer = Signal(0, name: 'layer');

  /// Everything the player holds. The per-resource signals below are views on
  /// it, so a readout can watch one resource without hearing about the rest.
  final Stockpile stock = Stockpile();

  Signal<BigDouble> get ore => stock.signal(ResourceId.ore);
  Signal<BigDouble> get crystals => stock.signal(ResourceId.crystals);
  Signal<BigDouble> get quantonium => stock.signal(ResourceId.quantonium);
  Signal<BigDouble> get samples => stock.signal(ResourceId.samples);
  Signal<BigDouble> get capsules => stock.signal(ResourceId.capsules);
  Signal<BigDouble> get cores => stock.signal(ResourceId.cores);
  Signal<BigDouble> get backgroundCompute => stock.signal(ResourceId.compute);

  /// A rig always has at least one drill: total power is a product, and a
  /// count of zero would mean the game could never start.
  final Signal<int> drills = Signal(1, name: 'drills');

  /// Ore-bought upgrades to what a single drill delivers.
  final Signal<int> drillPowerLevel = Signal(0, name: 'drill power level');
  final Signal<int> modules = Signal(0, name: 'modules');
  final Signal<int> restarts = Signal(0, name: 'restarts');
  final Signal<int> charge = Signal(chargeCap, name: 'forcing charge');
  final Signal<bool> forcing = Signal(false, name: 'forcing');

  /// Tree levels. Purchasing is not wired up yet; they exist so the formulas
  /// read the way the prototype's do.
  final Signal<int> powerLevel = Signal(0, name: 'power level');
  final Signal<int> enrichmentLevel = Signal(0, name: 'enrichment level');
  final Signal<int> discountLevel = Signal(0, name: 'discount level');
  final Signal<int> quantoniumLevel = Signal(0, name: 'quantonium level');

  /// Damage already taken by the current layer, kept between cycles.
  final Signal<BigDouble> layerHp = Signal(BigDouble.zero, name: 'layer hp');
  final Signal<BigDouble> layerHpMax = Signal(
    BigDouble.one,
    name: 'layer hp max',
  );

  late final Computed<BigDouble> layerDensity;
  late final Computed<BigDouble> power;
  late final Computed<BigDouble> perDrillPower;
  late final Computed<BigDouble> powerUpgradeCost;
  late final Computed<BigDouble> orePerCycle;
  late final Computed<BigDouble> drillCost;
  late final Computed<int> cyclesToBreak;

  static const int chargeCap = 100;

  /// What one forced cycle costs, paid IN ADVANCE.
  ///
  /// Charging on completion instead would hand the acceleration out free: a
  /// player tapping forcing on and off between ticks would shorten the
  /// interval and never reach the moment the gauge is read.
  static const int forcingCost = 4;

  /// What one unupgraded drill delivers per cycle.
  static const double basePerDrillPower = 10;

  /// Each upgrade multiplies a single drill's output by this.
  static const double perDrillGrowth = 1.2;

  /// The prototype caps damage carry-over here, so one enormous hit cannot
  /// tunnel through an unbounded number of layers in a single cycle.
  static const int maxLayersPerCycle = 25;

  static const int thickEvery = 25;

  /// A thick layer is three metres of rock in one piece: breaking it advances
  /// the depth by all three and pays out three times over, so its reward and
  /// its thickness are the same number rather than two to keep in step.
  static const int thickSpan = 3;

  /// Every twenty-fifth metre starts a thick layer.
  static bool isThick(int layer) => (layer + 1) % thickEvery == 0;

  /// How many metres a layer occupies.
  static int spanOf(int layer) => isThick(layer) ? thickSpan : 1;

  /// The metre the next layer starts at.
  static int nextLayer(int layer) => layer + spanOf(layer);

  /// The metre the layer covering [metre] starts at.
  ///
  /// Metres inside a thick layer are not layers of their own, so anything
  /// walking the stack has to land on the piece that contains them.
  static int layerStart(int metre) {
    final within = metre % thickEvery;
    if (metre >= thickEvery && within < thickSpan - 1) {
      return metre - within - 1;
    }
    return metre;
  }

  /// Density is a plain exponent with a stratum step every fifty metres.
  static BigDouble densityAt(int layer) {
    final base =
        BigDouble.fromNum(5) *
        BigDouble.fromNum(1.055).pow(layer.toDouble()) *
        BigDouble.fromNum(2.5).pow((layer ~/ 50).toDouble());
    return isThick(layer) ? base * BigDouble.fromNum(10) : base;
  }

  static int quantoniumDropAt(int layer) => 1 + layer ~/ 15;

  /// Crystals are not tied to a stratum: one mineral, worth more the deeper it
  /// is cut out of. Growth is geometric so the resource keeps pace with the
  /// rock it comes from instead of falling behind by the second stratum.
  static BigDouble crystalDropAt(int layer) =>
      BigDouble.fromNum(1.02).pow(layer.toDouble());

  static double _milestoneMultiplier(int owned) {
    var multiplier = 1.0;
    for (final threshold in const [10, 25, 50, 100]) {
      if (owned >= threshold) multiplier *= 2;
    }
    return multiplier;
  }

  double get criticalChance => 0.05;

  double get criticalMultiplier => 2;

  double get echoChance => 0.01;

  /// Rarer than quantonium up top and commoner far down, so the early game is
  /// ore-led and the mineral becomes the thing worth going deeper for.
  double get crystalChance {
    final chance = 0.08 + layer.value * 0.0012;
    return chance > 0.4 ? 0.4 : chance;
  }

  double get quantoniumChance {
    final chance = 0.12 + layer.value * 0.0015 + 0.02 * quantoniumLevel.value;
    return chance > 0.5 ? 0.5 : chance;
  }

  /// Runs one drilling cycle, including any echo cycles it triggers.
  ///
  /// Writes are batched so the UI hears about the whole cycle once rather than
  /// once per field touched.
  CycleOutcome tick() => batch(() => _cycle(0));

  /// Turns forcing on, paying for the cycle it is about to accelerate.
  ///
  /// Returns whether the gauge could cover it.
  bool beginForcing() {
    if (forcing.value) return true;
    if (!_payForForcing()) return false;
    forcing.value = true;
    return true;
  }

  /// Pays for one more forced cycle. Clears forcing when the gauge cannot.
  ///
  /// Whether to renew is the caller's to decide, because it is the caller that
  /// knows if the player is still asking for it. The cycle already paid for is
  /// never taken back: letting go mid-cycle stops the NEXT one, not the one in
  /// hand -- otherwise a tap would spend the charge and deliver nothing.
  bool renewForcing() {
    if (!forcing.value) return false;
    if (_payForForcing()) return true;
    forcing.value = false;
    return false;
  }

  void endForcing() => forcing.value = false;

  bool _payForForcing() {
    if (charge.value < forcingCost) return false;
    charge.value = charge.value - forcingCost;
    return true;
  }

  CycleOutcome _cycle(int chain) {
    final critical = random.stream('crit').chance(criticalChance);
    final multiplier = critical
        ? BigDouble.fromNum(criticalMultiplier)
        : BigDouble.one;

    final gained = orePerCycle.value * multiplier;
    stock.add(ResourceId.ore, gained);

    // Its own substream: adding a roll to the cycle must not shift every roll
    // that follows it and turn the parity tests red.
    var crystalsGained = BigDouble.zero;
    if (random.stream('crystal').chance(crystalChance)) {
      crystalsGained = crystalDropAt(layer.value) * multiplier;
      stock.add(ResourceId.crystals, crystalsGained);
    }

    var quantoniumGained = 0;
    if (random.stream('quantonium').chance(quantoniumChance)) {
      quantoniumGained = quantoniumDropAt(layer.value);
      stock.add(ResourceId.quantonium, quantoniumGained.big);
    }

    var damage = power.value * multiplier;
    var broken = 0;
    var thickBroken = 0;
    while (damage > BigDouble.zero && broken < maxLayersPerCycle) {
      if (damage >= layerHp.value) {
        damage -= layerHp.value;
        if (_breakLayer()) thickBroken++;
        broken++;
      } else {
        layerHp.value = layerHp.value - damage;
        damage = BigDouble.zero;
      }
    }

    var echoes = 0;
    if (chain < 6 && random.stream('echo').chance(echoChance)) {
      echoes = 1 + _cycle(chain + 1).echoes;
    }

    return CycleOutcome(
      oreGained: gained,
      crystalsGained: crystalsGained,
      quantoniumGained: quantoniumGained,
      critical: critical,
      layersBroken: broken,
      thickLayersBroken: thickBroken,
      echoes: echoes,
    );
  }

  /// Returns whether the broken layer was a thick one.
  bool _breakLayer() {
    final thick = isThick(layer.value);
    if (thick) {
      final bonus = BigDouble.fromNum(thickSpan);
      stock.add(ResourceId.ore, orePerCycle.value * bonus);
      stock.add(ResourceId.crystals, crystalDropAt(layer.value) * bonus);
      stock.add(
        ResourceId.quantonium,
        (quantoniumDropAt(layer.value) * thickSpan).big,
      );
      stock.add(ResourceId.samples, BigDouble.one);
    } else {
      stock.add(ResourceId.ore, orePerCycle.value * BigDouble.fromNum(1.5));
    }

    layer.value = nextLayer(layer.value);
    _resetLayer();
    return thick;
  }

  void _resetLayer() {
    final density = densityAt(layer.value);
    layerHpMax.value = density;
    layerHp.value = density;
  }

  /// Regenerates one point of forcing charge. Driven by its own loop, which
  /// stops once the charge is full.
  void regenerateCharge() {
    if (charge.value >= chargeCap) return;
    charge.value = charge.value + 1;
  }

  bool get chargeFull => charge.value >= chargeCap;

  bool get canBuyDrill => stock.has(ResourceId.ore, drillCost.value);

  void buyDrill() {
    batch(() {
      if (!stock.spend(ResourceId.ore, drillCost.value)) return;
      drills.value = drills.value + 1;
    });
  }

  bool get canBuyPowerUpgrade =>
      stock.has(ResourceId.ore, powerUpgradeCost.value);

  void buyPowerUpgrade() {
    batch(() {
      if (!stock.spend(ResourceId.ore, powerUpgradeCost.value)) return;
      drillPowerLevel.value = drillPowerLevel.value + 1;
    });
  }

  /// The run, as a plain map.
  ///
  /// Derived values are left out and recomputed on the way back in: writing
  /// `layerHpMax` would let a save disagree with the density formula, and the
  /// formula has to win. Forcing is not written either -- it is a held button,
  /// and a save cannot hold one.
  Map<String, Object?> toJson() => {
    'layer': layer.value,
    'layerHp': layerHp.value.toJson(),
    'drills': drills.value,
    'drillPower': drillPowerLevel.value,
    'modules': modules.value,
    'restarts': restarts.value,
    'charge': charge.value,
    'tree': {
      'power': powerLevel.value,
      'enrichment': enrichmentLevel.value,
      'discount': discountLevel.value,
      'quantonium': quantoniumLevel.value,
    },
    'stock': stock.toJson(),
    'random': random.toJson(),
  };

  /// Restores a run written by [toJson].
  ///
  /// Anything missing falls back to the value a fresh run starts with, so a
  /// save written by an older build loads instead of throwing: sections the
  /// build does not know are the migration chain's problem, but absent keys
  /// inside a section it does know are not.
  void readJson(Map<String, Object?> json) => batch(() {
    layer.value = _readInt(json['layer'], 0);
    drills.value = _readInt(json['drills'], 1);
    drillPowerLevel.value = _readInt(json['drillPower'], 0);
    modules.value = _readInt(json['modules'], 0);
    restarts.value = _readInt(json['restarts'], 0);
    charge.value = _readInt(json['charge'], chargeCap).clamp(0, chargeCap);
    forcing.value = false;

    final tree = json['tree'];
    if (tree is Map) {
      powerLevel.value = _readInt(tree['power'], 0);
      enrichmentLevel.value = _readInt(tree['enrichment'], 0);
      discountLevel.value = _readInt(tree['discount'], 0);
      quantoniumLevel.value = _readInt(tree['quantonium'], 0);
    }

    final held = json['stock'];
    if (held is Map) {
      stock.readJson(Map<String, Object?>.from(held));
    }

    final rolls = json['random'];
    if (rolls is Map) {
      random = RandomSource.fromJson(Map<String, dynamic>.from(rolls));
    }

    _resetLayer();
    final damaged = json['layerHp'];
    if (damaged is String) {
      final remaining = BigDouble.parse(damaged);
      if (remaining > BigDouble.zero && remaining < layerHpMax.value) {
        layerHp.value = remaining;
      }
    }
  });

  static int _readInt(Object? value, int fallback) =>
      value is int ? value : fallback;

  /// The next drill-count milestone that doubles power, or null past the last.
  int? get nextMilestone {
    for (final threshold in const [10, 25, 50, 100]) {
      if (drills.value < threshold) return threshold;
    }
    return null;
  }

  /// What a single drill would deliver at the given upgrade level.
  BigDouble perDrillPowerWith(int upgrades) =>
      BigDouble.fromNum(basePerDrillPower) *
      BigDouble.fromNum(perDrillGrowth).pow(upgrades.toDouble());

  /// Total power for a hypothetical rig.
  ///
  /// Count and per-drill power are two separate levers that multiply, so the
  /// player chooses between more drills and better ones rather than being
  /// handed a single line to walk.
  BigDouble powerWith({required int drills, required int upgrades}) =>
      BigDouble.fromNum(drills) *
      perDrillPowerWith(upgrades) *
      BigDouble.fromNum(_milestoneMultiplier(drills)) *
      (BigDouble.one + BigDouble.fromNum(0.25) * modules.value.big);
}
