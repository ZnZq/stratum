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
    power = Computed(
      () => BigDouble.fromNum(10 + 6 * drills.value) *
          BigDouble.fromNum(_milestoneMultiplier(drills.value)) *
          BigDouble.fromNum(1.15).pow(powerLevel.value.toDouble()) *
          (BigDouble.one + BigDouble.fromNum(0.25) * modules.value.big),
      name: 'drill power',
    );
    orePerCycle = Computed(
      () => BigDouble.fromNum(1.6) *
          BigDouble.fromNum(1.03).pow(layer.value.toDouble()) *
          BigDouble.fromNum(1.2).pow(enrichmentLevel.value.toDouble()),
      name: 'ore per cycle',
    );
    drillCost = Computed(
      () => (BigDouble.fromNum(15) *
              BigDouble.fromNum(1.13).pow(drills.value.toDouble()) *
              BigDouble.fromNum(1 - 0.04 * discountLevel.value))
          .ceil(),
      name: 'drill cost',
    );
    cyclesToBreak = Computed(
      () {
        final remaining = layerHp.value;
        final perCycle = power.value;
        if (perCycle.isZero) return 1;
        final estimate = (remaining / perCycle).ceil().toDouble();
        return estimate < 1 ? 1 : estimate.toInt();
      },
      name: 'cycles to break',
    );

    _resetLayer();
  }

  final RandomSource random;

  final Signal<int> layer = Signal(0, name: 'layer');
  final Signal<BigDouble> ore = Signal(BigDouble.zero, name: 'ore');
  final Signal<BigDouble> quantonium = Signal(BigDouble.zero, name: 'quantonium');
  final Signal<int> drills = Signal(0, name: 'drills');
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
  final Signal<BigDouble> layerHpMax = Signal(BigDouble.one, name: 'layer hp max');

  late final Computed<BigDouble> layerDensity;
  late final Computed<BigDouble> power;
  late final Computed<BigDouble> orePerCycle;
  late final Computed<BigDouble> drillCost;
  late final Computed<int> cyclesToBreak;

  static const int chargeCap = 100;

  /// The prototype caps damage carry-over here, so one enormous hit cannot
  /// tunnel through an unbounded number of layers in a single cycle.
  static const int maxLayersPerCycle = 25;

  /// Every twenty-fifth metre is a thick layer.
  static bool isThick(int layer) => (layer + 1) % 25 == 0;

  /// Density is a plain exponent with a stratum step every fifty metres.
  static BigDouble densityAt(int layer) {
    final base = BigDouble.fromNum(5) *
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
  CycleOutcome tick() => batch(() => _cycle(0));

  CycleOutcome _cycle(int chain) {
    final critical = random.stream('crit').chance(criticalChance);
    final multiplier =
        critical ? BigDouble.fromNum(criticalMultiplier) : BigDouble.one;

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

    if (forcing.value) {
      final left = charge.value - 8;
      charge.value = left < 0 ? 0 : left;
      if (charge.value == 0) forcing.value = false;
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
      ore.value = ore.value + orePerCycle.value * BigDouble.fromNum(5);
      quantonium.value =
          quantonium.value + (quantoniumDropAt(layer.value) * 5).big;
      samples.value = samples.value + 1;
    } else {
      ore.value = ore.value + orePerCycle.value * BigDouble.fromNum(1.5);
    }

    layer.value = layer.value + 1;
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

  /// The next drill-count milestone that doubles power, or null past the last.
  int? get nextMilestone {
    for (final threshold in const [10, 25, 50, 100]) {
      if (drills.value < threshold) return threshold;
    }
    return null;
  }

  BigDouble powerAt(int drillCount) =>
      BigDouble.fromNum(10 + 6 * drillCount) *
      BigDouble.fromNum(_milestoneMultiplier(drillCount)) *
      BigDouble.fromNum(1.15).pow(powerLevel.value.toDouble()) *
      (BigDouble.one + BigDouble.fromNum(0.25) * modules.value.big);
}
