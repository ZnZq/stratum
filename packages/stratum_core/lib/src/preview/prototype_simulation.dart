import '../big_double.dart';
import '../random_source.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';

/// What one manual strike did.
class StrikeOutcome {
  const StrikeOutcome({
    required this.spent,
    required this.layersBroken,
    required this.thickLayersBroken,
    required this.regolithGained,
    required this.oresGained,
  });

  static const StrikeOutcome none = StrikeOutcome(
    spent: 0,
    layersBroken: 0,
    thickLayersBroken: 0,
    regolithGained: BigDouble.zero,
    oresGained: {},
  );

  final int spent;
  final int layersBroken;
  final int thickLayersBroken;
  final BigDouble regolithGained;

  /// The chance ores this blow happened to shake loose.
  final Map<ResourceId, BigDouble> oresGained;

  bool get landed => spent > 0;
}

/// What one drilling cycle produced, for the UI to turn into feedback.
class CycleOutcome {
  const CycleOutcome({
    required this.regolithGained,
    required this.crystalsGained,
    required this.quantoniumGained,
    required this.critical,
    required this.layersBroken,
    required this.thickLayersBroken,
    required this.echoes,
  });

  static const CycleOutcome none = CycleOutcome(
    regolithGained: BigDouble.zero,
    crystalsGained: BigDouble.zero,
    quantoniumGained: 0,
    critical: false,
    layersBroken: 0,
    thickLayersBroken: 0,
    echoes: 0,
  );

  final BigDouble regolithGained;
  final BigDouble crystalsGained;
  final int quantoniumGained;
  final bool critical;
  final int layersBroken;
  final int thickLayersBroken;
  final int echoes;
}

/// What an absence paid out.
class OfflineGain {
  const OfflineGain({
    required this.cycles,
    required this.efficiency,
    required this.ore,
    required this.crystals,
    required this.quantonium,
    required this.ores,
  });

  static const OfflineGain none = OfflineGain(
    cycles: 0,
    efficiency: 0,
    ore: BigDouble.zero,
    crystals: BigDouble.zero,
    quantonium: BigDouble.zero,
    ores: {},
  );

  final int cycles;
  final double efficiency;
  final BigDouble ore;
  final BigDouble crystals;
  final BigDouble quantonium;

  /// The chance ores that were unlocked over the absence.
  final Map<ResourceId, BigDouble> ores;

  bool get isEmpty => cycles <= 0;
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
    regolithPerCycle = Computed(
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
    hitsToBreak = Computed(() {
      final remaining = layerHp.value;
      final perCycle = power.value;
      if (perCycle.isZero) return 1;
      final estimate = (remaining / perCycle).ceil().toDouble();
      return estimate < 1 ? 1 : estimate.toInt();
    }, name: 'hits to break');

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

  Signal<BigDouble> get regolith => stock.signal(ResourceId.regolith);
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
  final Signal<int> energy = Signal(energyCapBase, name: 'energy');

  /// Regolith-bought upgrades to the manual lane.
  final Signal<int> strikeLevel = Signal(0, name: 'strike level');
  final Signal<int> energyCapLevel = Signal(0, name: 'energy cap level');
  final Signal<int> energyRegenLevel = Signal(0, name: 'energy regen level');

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
  late final Computed<BigDouble> regolithPerCycle;
  late final Computed<BigDouble> drillCost;
  late final Computed<int> hitsToBreak;

  static const int energyCapBase = 100;

  /// Each capacity level adds this many points to the gauge.
  static const int energyPerCapLevel = 25;

  int get energyCap => energyCapBase + energyPerCapLevel * energyCapLevel.value;

  /// How much one regen tick pours in.
  int get energyPerRegen => 1 + energyRegenLevel.value;

  /// Each strike level multiplies the blow by this.
  static const double strikeGrowth = 1.35;

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

  /// The chance ores, each opened by a stratum boundary.
  ///
  /// PROVISIONAL numbers, like everything in this class. What is meant to
  /// last is the shape: a new ore is a row here with its own roll stream,
  /// and nothing else -- the cycle walks this table instead of naming ores.
  static const List<
    ({ResourceId id, String stream, int unlockAt, double chance})
  >
  oreTable = [
    (id: ResourceId.cuprite, stream: 'cuprite', unlockAt: 0, chance: 0.22),
    (id: ResourceId.ferrite, stream: 'ferrite', unlockAt: 50, chance: 0.15),
    (id: ResourceId.silicite, stream: 'silicite', unlockAt: 100, chance: 0.12),
  ];

  /// How much of an ore one successful roll yields at [layer].
  static BigDouble oreDropAt(int layer) => BigDouble.fromNum(1 + layer * 0.03);

  bool oreUnlocked(ResourceId id) {
    for (final row in oreTable) {
      if (row.id == id) return layer.value >= row.unlockAt;
    }
    return false;
  }

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

  /// The offline throttle: absence produces at a quarter of live pace.
  static const double offlineEfficiency = 0.25;

  /// Settles an absence as one formula over the whole span -- never a step
  /// replay.
  ///
  /// Chance drops arrive at their expected value instead of being rolled:
  /// thousands of draws would drain the substreams and shift every roll that
  /// follows a comeback, turning parity tests red. Depth does not move --
  /// drilling is the online game; what the store earns while away is ore and
  /// minerals at the current face.
  OfflineGain claimOffline({
    required int cycles,
    double efficiency = offlineEfficiency,
  }) {
    if (cycles <= 0) return OfflineGain.none;
    final scale = BigDouble.fromNum(cycles) * BigDouble.fromNum(efficiency);
    final ore = regolithPerCycle.value * scale;
    final crystals =
        crystalDropAt(layer.value) * BigDouble.fromNum(crystalChance) * scale;
    final quantonium =
        BigDouble.fromNum(quantoniumDropAt(layer.value) * quantoniumChance) *
        scale;
    final ores = <ResourceId, BigDouble>{
      for (final row in oreTable)
        if (layer.value >= row.unlockAt)
          row.id:
              oreDropAt(layer.value) * BigDouble.fromNum(row.chance) * scale,
    };
    batch(() {
      stock.add(ResourceId.regolith, ore);
      stock.add(ResourceId.crystals, crystals);
      stock.add(ResourceId.quantonium, quantonium);
      for (final entry in ores.entries) {
        stock.add(entry.key, entry.value);
      }
    });
    return OfflineGain(
      cycles: cycles,
      efficiency: efficiency,
      ore: ore,
      crystals: crystals,
      quantonium: quantonium,
      ores: ores,
    );
  }

  /// Runs one drilling cycle, including any echo cycles it triggers.
  ///
  /// Writes are batched so the UI hears about the whole cycle once rather than
  /// once per field touched.
  CycleOutcome tick() => batch(() => _cycle(0));

  /// What one manual strike costs.
  static const int strikeCost = 1;

  /// The floor a strike never falls under, so the game opens playable with no
  /// rig at all.
  static const double baseStrikePower = 8;

  /// A strike scales with the rig: a flat hit would be noise by the second
  /// stratum and the active lane would quietly die.
  static const double strikeShareOfRig = 0.35;

  BigDouble get strikePower => strikePowerAt(strikeLevel.value);

  BigDouble strikePowerAt(int level) {
    final scaled = power.value * BigDouble.fromNum(strikeShareOfRig);
    final floor = BigDouble.fromNum(baseStrikePower);
    final resting = scaled > floor ? scaled : floor;
    return resting * BigDouble.fromNum(strikeGrowth).pow(level.toDouble());
  }

  BigDouble get strikeUpgradeCost =>
      (BigDouble.fromNum(120) *
              BigDouble.fromNum(2.1).pow(strikeLevel.value.toDouble()))
          .ceil();

  BigDouble get energyCapUpgradeCost =>
      (BigDouble.fromNum(150) *
              BigDouble.fromNum(2.0).pow(energyCapLevel.value.toDouble()))
          .ceil();

  BigDouble get energyRegenUpgradeCost =>
      (BigDouble.fromNum(200) *
              BigDouble.fromNum(2.4).pow(energyRegenLevel.value.toDouble()))
          .ceil();

  bool get canBuyStrikeUpgrade =>
      stock.has(ResourceId.regolith, strikeUpgradeCost);

  bool get canBuyEnergyCapUpgrade =>
      stock.has(ResourceId.regolith, energyCapUpgradeCost);

  bool get canBuyEnergyRegenUpgrade =>
      stock.has(ResourceId.regolith, energyRegenUpgradeCost);

  void buyStrikeUpgrade() {
    batch(() {
      if (!stock.spend(ResourceId.regolith, strikeUpgradeCost)) return;
      strikeLevel.value = strikeLevel.value + 1;
    });
  }

  void buyEnergyCapUpgrade() {
    batch(() {
      if (!stock.spend(ResourceId.regolith, energyCapUpgradeCost)) return;
      energyCapLevel.value = energyCapLevel.value + 1;
    });
  }

  void buyEnergyRegenUpgrade() {
    batch(() {
      if (!stock.spend(ResourceId.regolith, energyRegenUpgradeCost)) return;
      energyRegenLevel.value = energyRegenLevel.value + 1;
    });
  }

  /// One manual blow at the face: spends energy, deals [strikePower], and
  /// mines.
  ///
  /// A strike and a drill tick are the same event at different powers: hit
  /// the rock, take out what the hit is worth. The yield is the cycle's,
  /// scaled by the power ratio, so the two lanes stay on one economy instead
  /// of being balanced against each other. Ores roll at the same scaled
  /// expectation on their own `strike.*` streams; crystals and quantonium
  /// stay cycle-only (the anti-brick drip belongs to the heartbeat), and
  /// there is no crit roll -- crits are the drill's drama.
  StrikeOutcome strike() => batch(() {
    if (energy.value < strikeCost) return StrikeOutcome.none;
    energy.value = energy.value - strikeCost;

    final share = strikePower / power.value;
    final regolith = regolithPerCycle.value * share;
    stock.add(ResourceId.regolith, regolith);

    final fraction = share.toDouble();
    final ores = <ResourceId, BigDouble>{};
    for (final row in oreTable) {
      if (layer.value < row.unlockAt) continue;
      final chance = row.chance * fraction;
      if (random
          .stream('strike.${row.stream}')
          .chance(chance > 1 ? 1 : chance)) {
        final drop = oreDropAt(layer.value);
        stock.add(row.id, drop);
        ores[row.id] = drop;
      }
    }

    final result = _applyDamage(strikePower);
    return StrikeOutcome(
      spent: strikeCost,
      layersBroken: result.broken,
      thickLayersBroken: result.thickBroken,
      regolithGained: regolith,
      oresGained: ores,
    );
  });

  CycleOutcome _cycle(int chain) {
    final critical = random.stream('crit').chance(criticalChance);
    final multiplier = critical
        ? BigDouble.fromNum(criticalMultiplier)
        : BigDouble.one;

    final gained = regolithPerCycle.value * multiplier;
    stock.add(ResourceId.regolith, gained);

    // Its own substream: adding a roll to the cycle must not shift every roll
    // that follows it and turn the parity tests red.
    var crystalsGained = BigDouble.zero;
    if (random.stream('crystal').chance(crystalChance)) {
      crystalsGained = crystalDropAt(layer.value) * multiplier;
      stock.add(ResourceId.crystals, crystalsGained);
    }

    for (final row in oreTable) {
      if (layer.value < row.unlockAt) continue;
      if (random.stream(row.stream).chance(row.chance)) {
        stock.add(row.id, oreDropAt(layer.value) * multiplier);
      }
    }

    var quantoniumGained = 0;
    if (random.stream('quantonium').chance(quantoniumChance)) {
      quantoniumGained = quantoniumDropAt(layer.value);
      stock.add(ResourceId.quantonium, quantoniumGained.big);
    }

    final struck = _applyDamage(power.value * multiplier);
    final broken = struck.broken;
    final thickBroken = struck.thickBroken;

    var echoes = 0;
    if (chain < 6 && random.stream('echo').chance(echoChance)) {
      echoes = 1 + _cycle(chain + 1).echoes;
    }

    return CycleOutcome(
      regolithGained: gained,
      crystalsGained: crystalsGained,
      quantoniumGained: quantoniumGained,
      critical: critical,
      layersBroken: broken,
      thickLayersBroken: thickBroken,
      echoes: echoes,
    );
  }

  /// Drives [damage] into the face, carrying overflow into deeper layers.
  ({int broken, int thickBroken}) _applyDamage(BigDouble damage) {
    var remaining = damage;
    var broken = 0;
    var thickBroken = 0;
    while (remaining > BigDouble.zero && broken < maxLayersPerCycle) {
      if (remaining >= layerHp.value) {
        remaining -= layerHp.value;
        if (_breakLayer()) thickBroken++;
        broken++;
      } else {
        layerHp.value = layerHp.value - remaining;
        remaining = BigDouble.zero;
      }
    }
    return (broken: broken, thickBroken: thickBroken);
  }

  /// Returns whether the broken layer was a thick one.
  bool _breakLayer() {
    final thick = isThick(layer.value);
    if (thick) {
      final bonus = BigDouble.fromNum(thickSpan);
      stock.add(ResourceId.regolith, regolithPerCycle.value * bonus);
      stock.add(ResourceId.crystals, crystalDropAt(layer.value) * bonus);
      for (final row in oreTable) {
        if (layer.value < row.unlockAt) continue;
        stock.add(row.id, oreDropAt(layer.value) * bonus);
      }
      stock.add(
        ResourceId.quantonium,
        (quantoniumDropAt(layer.value) * thickSpan).big,
      );
      stock.add(ResourceId.samples, BigDouble.one);
    } else {
      stock.add(
        ResourceId.regolith,
        regolithPerCycle.value * BigDouble.fromNum(1.5),
      );
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

  /// Regenerates one point of energy. Driven by its own loop, which stops
  /// once the gauge is full.
  void regenerateEnergy() {
    if (energy.value >= energyCap) return;
    final next = energy.value + energyPerRegen;
    energy.value = next > energyCap ? energyCap : next;
  }

  bool get energyFull => energy.value >= energyCap;

  bool get canBuyDrill => stock.has(ResourceId.regolith, drillCost.value);

  void buyDrill() {
    batch(() {
      if (!stock.spend(ResourceId.regolith, drillCost.value)) return;
      drills.value = drills.value + 1;
    });
  }

  bool get canBuyPowerUpgrade =>
      stock.has(ResourceId.regolith, powerUpgradeCost.value);

  void buyPowerUpgrade() {
    batch(() {
      if (!stock.spend(ResourceId.regolith, powerUpgradeCost.value)) return;
      drillPowerLevel.value = drillPowerLevel.value + 1;
    });
  }

  /// The run, as a plain map.
  ///
  /// Derived values are left out and recomputed on the way back in: writing
  /// `layerHpMax` would let a save disagree with the density formula, and the
  /// formula has to win.
  Map<String, Object?> toJson() => {
    'layer': layer.value,
    'layerHp': layerHp.value.toJson(),
    'drills': drills.value,
    'drillPower': drillPowerLevel.value,
    'modules': modules.value,
    'restarts': restarts.value,
    'energy': energy.value,
    'strikes': {
      'power': strikeLevel.value,
      'cap': energyCapLevel.value,
      'regen': energyRegenLevel.value,
    },
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
    final strikes = json['strikes'];
    if (strikes is Map) {
      strikeLevel.value = _readInt(strikes['power'], 0);
      energyCapLevel.value = _readInt(strikes['cap'], 0);
      energyRegenLevel.value = _readInt(strikes['regen'], 0);
    } else {
      strikeLevel.value = 0;
      energyCapLevel.value = 0;
      energyRegenLevel.value = 0;
    }
    energy.value = _readInt(json['energy'], energyCap).clamp(0, energyCap);

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
