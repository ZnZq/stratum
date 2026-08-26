import '../big_double.dart';
import '../random_source.dart';
import '../reactive_graph.dart';

/// What one drilling cycle produced, for the UI to turn into feedback.
class CycleOutcome {
  const CycleOutcome({
    required this.oreGained,
    required this.quantoniumGained,
    required this.critical,
    required this.layersBroken,
    required this.thickLayersBroken,
    required this.echoes,
  });

  static const CycleOutcome none = CycleOutcome(
    oreGained: BigDouble.zero,
    quantoniumGained: 0,
    critical: false,
    layersBroken: 0,
    thickLayersBroken: 0,
    echoes: 0,
  );

  final BigDouble oreGained;
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

  final RandomSource random;

  final Signal<int> layer = Signal(0, name: 'layer');
  final Signal<BigDouble> ore = Signal(BigDouble.zero, name: 'ore');
  final Signal<BigDouble> quantonium = Signal(
    BigDouble.zero,
    name: 'quantonium',
  );

  /// A rig always has at least one drill: total power is a product, and a
  /// count of zero would mean the game could never start.
  final Signal<int> drills = Signal(1, name: 'drills');

  /// Ore-bought upgrades to what a single drill delivers.
  final Signal<int> drillPowerLevel = Signal(0, name: 'drill power level');
  final Signal<int> modules = Signal(0, name: 'modules');
  final Signal<int> samples = Signal(0, name: 'samples');
  final Signal<int> capsules = Signal(0, name: 'capsules');
  final Signal<int> backgroundCompute = Signal(0, name: 'background compute');
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

  double get quantoniumChance {
    final chance = 0.12 + layer.value * 0.0015 + 0.02 * quantoniumLevel.value;
    return chance > 0.5 ? 0.5 : chance;
  }

  /// Runs one drilling cycle, including any echo cycles it triggers.
  ///
  /// Writes are batched so the UI hears about the whole cycle once rather than
  /// once per field touched.
  CycleOutcome tick() => batch(() {
    final outcome = _cycle(0);
    // The cycle just paid for is over; forcing only continues if the gauge
    // can cover the next one before it starts.
    if (forcing.value && !_payForForcing()) forcing.value = false;
    return outcome;
  });

  /// Turns forcing on, paying for the cycle it is about to accelerate.
  ///
  /// Returns whether the gauge could cover it.
  bool beginForcing() {
    if (forcing.value) return true;
    if (!_payForForcing()) return false;
    forcing.value = true;
    return true;
  }

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
    ore.value = ore.value + gained;

    var quantoniumGained = 0;
    if (random.stream('quantonium').chance(quantoniumChance)) {
      quantoniumGained = quantoniumDropAt(layer.value);
      quantonium.value = quantonium.value + quantoniumGained.big;
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
      ore.value = ore.value + orePerCycle.value * BigDouble.fromNum(thickSpan);
      quantonium.value =
          quantonium.value + (quantoniumDropAt(layer.value) * thickSpan).big;
      samples.value = samples.value + 1;
    } else {
      ore.value = ore.value + orePerCycle.value * BigDouble.fromNum(1.5);
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

  bool get canBuyDrill => ore.value.gteWithTolerance(drillCost.value);

  void buyDrill() {
    if (!canBuyDrill) return;
    batch(() {
      ore.value = ore.value - drillCost.value;
      drills.value = drills.value + 1;
    });
  }

  bool get canBuyPowerUpgrade =>
      ore.value.gteWithTolerance(powerUpgradeCost.value);

  void buyPowerUpgrade() {
    if (!canBuyPowerUpgrade) return;
    batch(() {
      ore.value = ore.value - powerUpgradeCost.value;
      drillPowerLevel.value = drillPowerLevel.value + 1;
    });
  }

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
