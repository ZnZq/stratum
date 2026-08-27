import 'dart:math' as math;

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
    required this.critical,
  });

  static const StrikeOutcome none = StrikeOutcome(
    spent: 0,
    layersBroken: 0,
    thickLayersBroken: 0,
    regolithGained: BigDouble.zero,
    oresGained: {},
    critical: false,
  );

  final int spent;
  final int layersBroken;
  final int thickLayersBroken;
  final BigDouble regolithGained;

  /// Whether this blow critted, multiplying its damage and haul alike.
  final bool critical;

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
    required this.seconds,
    required this.cycles,
    required this.efficiency,
    required this.gained,
  });

  static const OfflineGain none = OfflineGain(
    seconds: 0,
    cycles: 0,
    efficiency: 0,
    gained: {},
  );

  /// How long the player was away.
  final double seconds;

  /// The same span counted in drill cycles, for a readout that speaks in
  /// heartbeats rather than in seconds.
  final int cycles;

  final double efficiency;

  /// Everything earned, by resource. One flat map for the same reason the
  /// stockpile is one: a resource added later is an entry here, not a new
  /// field wired into every place that shows the haul.
  final Map<ResourceId, BigDouble> gained;

  bool get isEmpty => gained.isEmpty;
}

/// The three parts of the manipulator arm the player upgrades.
///
/// Named after the hardware rather than the stat, because a part carries
/// several buffs at once and grows more of them as it evolves.
enum ArmPart {
  /// What the arm strikes with: the blow's own power, and the floor of what
  /// it brings back.
  bit,

  /// What drives the bit into the face: how deep a blow bites into what is
  /// still standing, and the ceiling of the haul.
  drive,

  /// The pack in the shoulder: how many blows are in the magazine and how
  /// fast it refills.
  supply,
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
      // Counted at the strike's power, not the rig's: the readout answers
      // the finger on the rock, and the drill's own blow is on its card.
      // Each blow is power plus the structural share of what still stands,
      // so the count follows the geometric shrink, not plain division.
      final remaining = layerHp.value;
      final perHit = strikePower;
      if (perHit.isZero) return 1;
      final share = pierceShare;
      final ratio = (remaining / perHit) * BigDouble.fromNum(share);
      final estimate = ((BigDouble.one + ratio).ln() / -math.log(1 - share))
          .ceilToDouble();
      return estimate < 1 ? 1 : estimate.toInt();
    }, name: 'hits to break');
    bankableData = Computed(() {
      final due = walletEarned - dataBanked.value;
      return due > BigDouble.zero ? due : BigDouble.zero;
    }, name: 'bankable data');

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
  Signal<BigDouble> get credits => stock.signal(ResourceId.credits);
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

  /// The three parts of the manipulator arm, each its own upgrade track.
  ///
  /// One track per PART rather than one per stat: a part carries several
  /// buffs at once, and later generations of it add more. The player upgrades
  /// a piece of hardware, not a number.
  final Signal<int> bitLevel = Signal(0, name: 'bit level');
  final Signal<int> driveLevel = Signal(0, name: 'drive level');
  final Signal<int> supplyLevel = Signal(0, name: 'supply level');

  /// Tree levels. Purchasing is not wired up yet; they exist so the formulas
  /// read the way the prototype's do.
  final Signal<int> powerLevel = Signal(0, name: 'power level');
  final Signal<int> enrichmentLevel = Signal(0, name: 'enrichment level');
  final Signal<int> discountLevel = Signal(0, name: 'discount level');
  final Signal<int> quantoniumLevel = Signal(0, name: 'quantonium level');

  /// Raw data of the current simulation. Feeds the collapse gate; a restart
  /// resets it.
  final Signal<BigDouble> rawData = Signal(BigDouble.zero, name: 'raw data');

  /// Raw data of the whole cycle, across restarts. Feeds the wallet
  /// function; only a collapse resets it.
  final Signal<BigDouble> cycleData = Signal(
    BigDouble.zero,
    name: 'cycle data',
  );

  /// What the wallet function has already paid out this cycle. Banking is a
  /// difference, so restarting sooner or later never changes a cycle's total.
  final Signal<BigDouble> dataBanked = Signal(
    BigDouble.zero,
    name: 'data banked',
  );

  /// Banked data not yet spent on the simulation tree.
  final Signal<BigDouble> dataWallet = Signal(
    BigDouble.zero,
    name: 'data wallet',
  );

  /// Purchased levels of the wallet exponent. Buying is not wired up yet.
  final Signal<int> dataExponentLevel = Signal(0, name: 'data exponent level');

  /// Collapses performed, ever.
  final Signal<int> collapses = Signal(0, name: 'collapses');

  /// Wall-clock epoch ms the cycle began, for the drift formula. Zero means
  /// not stamped yet: the app stamps it, keeping DateTime out of the core.
  final Signal<int> cycleStartMs = Signal(0, name: 'cycle start');

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
  late final Computed<BigDouble> bankableData;

  static const int energyCapBase = 250;

  /// Each supply level adds this many points to the gauge.
  static const int energyPerCapLevel = 10;

  int get energyCap => energyCapBase + energyPerCapLevel * supplyLevel.value;

  /// A regen tick always pours in exactly one point. What the supply upgrade
  /// buys is a SHORTER wait, not a bigger pour: the sustained strike rate is
  /// then literally the regen rate, and the gauge's ceiling stays what it is
  /// -- the length of a burst.
  int get energyPerRegen => 1;

  /// The wait between two points at rest.
  static const double baseEnergySeconds = 2.0;

  /// Each supply level adds this share to the regen RATE, additively: five
  /// hundred levels come out at +50%, so the wait bottoms out at 1.333 s.
  /// Speeding the rate rather than shortening the wait is what keeps the
  /// formula from crossing zero at the top of the track.
  static const double regenSpeedPerLevel = 0.001;

  double get energySeconds =>
      baseEnergySeconds / (1 + regenSpeedPerLevel * supplyLevel.value);

  /// Every part levels to here, in five generations of a hundred.
  static const int maxPartLevel = 500;
  static const int levelsPerGeneration = 100;

  /// Which generation a level belongs to, from 0 (Mk I) to 4 (Mk V).
  static int generationOf(int level) {
    final generation = level ~/ levelsPerGeneration;
    final last = maxPartLevel ~/ levelsPerGeneration - 1;
    return generation > last ? last : generation;
  }

  /// PROVISIONAL buff rates. Balance comes later; what is meant to last is
  /// that each part carries several of these at once.
  static const double basePowerPerLevel = 10;
  static const double minRegolithGrowth = 1.03;
  static const double maxRegolithGrowth = 1.05;
  static const double piercePerLevel = 0.00001;

  /// What one unupgraded drill delivers per cycle.
  static const double basePerDrillPower = 10;

  /// Each upgrade multiplies a single drill's output by this.
  static const double perDrillGrowth = 1.2;

  /// The prototype caps damage carry-over here, so one enormous hit cannot
  /// tunnel through an unbounded number of layers in a single cycle.
  static const int maxLayersPerCycle = 25;

  /// The share of a layer's REMAINING hp every blow collapses on top of its
  /// own power: crumbling structure, not extra muscle. Off the remainder
  /// rather than the maximum, so a wall costs log-of-overmatch blows and the
  /// kill itself always belongs to the blow's power. PROVISIONAL.
  static const double structuralShare = 0.0002;

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
  double get crystalChance => crystalChanceAt(layer.value);

  static double crystalChanceAt(int layer) {
    final chance = 0.08 + layer * 0.0012;
    return chance > 0.4 ? 0.4 : chance;
  }

  double get quantoniumChance {
    final chance = 0.12 + layer.value * 0.0015 + 0.02 * quantoniumLevel.value;
    return chance > 0.5 ? 0.5 : chance;
  }

  /// The wallet exponent and its upgrade track. Data is counted in
  /// measurements rather than in tonnes, so the gross it compresses grows
  /// with play instead of exploding with the economy -- which is why the
  /// exponent can be this gentle and still keep the wallet in readable
  /// numbers. Each purchased step multiplies a cycle's whole earnings by
  /// gross^step, so it stays capped. PROVISIONAL.
  static const double dataExponentBase = 0.25;
  static const double dataExponentStep = 0.01;
  static const double dataExponentMax = 0.35;

  /// The oversaturation gate: one run's raw data reaching this allows a
  /// collapse. Sized against the accrual below so a first collapse is days
  /// of play, not minutes. PROVISIONAL.
  static final BigDouble collapseThresholdBase = BigDouble.fromNum(3e8);

  /// What the gate is multiplied by per collapse already performed. Later
  /// cycles reach far deeper far sooner, and data accrues with depth, so a
  /// fixed gate would fall in hours by the fifth cycle. PROVISIONAL.
  static const double collapseThresholdGrowth = 4;

  /// Drift: the collapse threshold melts by this factor per wall-clock day,
  /// online and offline alike, with no floor.
  static const double collapseDriftPerDay = 0.97;

  int get simulationNumber => restarts.value + 1;

  int get cycleNumber => collapses.value + 1;

  double get dataExponent {
    final exponent =
        dataExponentBase + dataExponentStep * dataExponentLevel.value;
    return exponent > dataExponentMax ? dataExponentMax : exponent;
  }

  /// Everything the wallet function has earned over the cycle so far.
  BigDouble get walletEarned => cycleData.value.isZero
      ? BigDouble.zero
      : cycleData.value.pow(dataExponent);

  /// The collapse threshold at [nowMs], melted by drift since the cycle
  /// began. A zero start means the app has not stamped the cycle yet, and a
  /// clock wound backwards counts as no time passed.
  BigDouble collapseThreshold(int nowMs) {
    final base =
        collapseThresholdBase *
        BigDouble.fromNum(collapseThresholdGrowth)
            .pow(collapses.value.toDouble());
    final start = cycleStartMs.value;
    if (start <= 0 || nowMs <= start) return base;
    final days = (nowMs - start) / Duration.millisecondsPerDay;
    return base *
        BigDouble.fromNum(math.pow(collapseDriftPerDay, days).toDouble());
  }

  /// Whether one run's raw data has oversaturated the simulation.
  bool collapseReady(int nowMs) =>
      rawData.value.gteWithTolerance(collapseThreshold(nowMs));

  /// One haul as MEASUREMENTS rather than as tonnes: how many typical drops
  /// of its kind this is, over how often a drop of that kind is seen.
  ///
  /// Normalising against the depth's own drop is what keeps the data honest.
  /// Amounts inflate exponentially with depth -- regolith alone is 1.03^m --
  /// so counting them raw made a strike at 400 m worth tens of thousands of
  /// strikes at the surface, and any fixed collapse gate fell in minutes.
  /// A sighting is a sighting; what makes a deep one worth more is the depth
  /// factor in [_recordData], not the tonnage. Dividing by the chance keeps
  /// the rarer lane worth more per sighting, so every lane's expected
  /// contribution per strike comes out at exactly one.
  BigDouble _information(BigDouble amount, BigDouble typical, double chance) {
    if (typical.isZero) return BigDouble.zero;
    return amount / typical / BigDouble.fromNum(chance);
  }

  /// Books measurements as data at the depth they were taken.
  ///
  /// The depth factor is floored at one metre so the surface still counts.
  void _recordData(BigDouble weighted) {
    if (weighted.isZero) return;
    final gained = weighted * BigDouble.fromNum(layer.value + 1);
    rawData.value = rawData.value + gained;
    cycleData.value = cycleData.value + gained;
  }

  /// The offline throttle: absence produces at a quarter of live pace.
  static const double offlineEfficiency = 0.25;

  /// Settles an absence as one formula over the whole span -- never a step
  /// replay.
  ///
  /// An absence pays [efficiency] of what the same stretch of playing would
  /// have paid, off the very [yieldPerSecond] the warehouse quotes: both
  /// lanes, at the cadences handed in. One source rather than two, so a new
  /// ore joins the loot table, the readout and the absence in a single row of
  /// [oreTable] instead of in three places that can drift apart.
  ///
  /// Chance drops arrive at their expected value instead of being rolled:
  /// thousands of draws would drain the substreams and shift every roll that
  /// follows a comeback, turning parity tests red. Depth does not move --
  /// drilling is the online game; what the store earns while away is ore and
  /// minerals at the current face, which is also why break payouts are not
  /// part of the rate.
  OfflineGain claimOffline({
    required double seconds,
    required double energyPerSecond,
    required double cycleSeconds,
    double efficiency = offlineEfficiency,
  }) {
    if (seconds <= 0 || efficiency <= 0) return OfflineGain.none;
    final span = BigDouble.fromNum(seconds * efficiency);
    final gained = <ResourceId, BigDouble>{};
    for (final id in ResourceId.values) {
      final rate = yieldPerSecond(
        id,
        energyPerSecond: energyPerSecond,
        cycleSeconds: cycleSeconds,
      );
      if (rate.isZero) continue;
      gained[id] = rate * span;
    }
    if (gained.isEmpty) return OfflineGain.none;

    // Every lane that pays expects one sighting per strike, so the data an
    // absence books is the strikes it stands for times the lanes open.
    final strikesPerSecond =
        energyPerSecond / strikeCost +
        (cycleSeconds > 0 ? 1 / cycleSeconds : 0);

    batch(() {
      for (final entry in gained.entries) {
        stock.add(entry.key, entry.value);
      }
      _recordData(
        BigDouble.fromNum(
          gained.length * strikesPerSecond * seconds * efficiency,
        ),
      );
    });
    return OfflineGain(
      seconds: seconds,
      cycles: cycleSeconds > 0 ? (seconds / cycleSeconds).floor() : 0,
      efficiency: efficiency,
      gained: gained,
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

  /// The regolith haul of one strike is a roll, not a constant: this is the
  /// half-width of the band around the mean.
  static const double regolithSpread = 0.2;

  /// Quantonium can shake loose from any strike, but rarely: the reliable
  /// drip stays with the cycle, this is a bonus glint.
  static const double strikeQuantoniumChance = 0.02;

  /// A strike's own crit: one roll that multiplies the whole blow -- the
  /// damage dealt and the haul taken alike.
  static const double strikeCritChance = 0.05;
  static const double strikeCritPower = 1.20;

  /// The band a strike's regolith lands in.
  ///
  /// The two ends move on different parts: the bit raises the FLOOR (a
  /// heavier head never comes back empty) and the drive raises the CEILING
  /// (a harder blow is what shakes a jackpot loose). PROVISIONAL rates.
  BigDouble get strikeRegolithMin =>
      _strikeRegolithMean *
      BigDouble.fromNum(1 - regolithSpread) *
      BigDouble.fromNum(minRegolithGrowth).pow(bitLevel.value.toDouble());

  BigDouble get strikeRegolithMax =>
      _strikeRegolithMean *
      BigDouble.fromNum(1 + regolithSpread) *
      BigDouble.fromNum(maxRegolithGrowth).pow(driveLevel.value.toDouble());

  BigDouble get _strikeRegolithMean =>
      regolithPerCycle.value * BigDouble.fromNum(strikeShareOfRig);

  /// What the arm swings on its own, before the rig is consulted.
  BigDouble armPowerAt(int level) =>
      BigDouble.fromNum(baseStrikePower + basePowerPerLevel * level);

  /// How much of the layer's REMAINING hp every blow collapses, the drive's
  /// own buff on top of the floor every blow has.
  double get pierceShare => structuralShare + piercePerLevel * driveLevel.value;

  BigDouble get strikePower => strikePowerAt(bitLevel.value);

  /// The blow, never weaker than a share of the rig: an arm that could not
  /// keep up with its own drills would make the manual lane noise by the
  /// second stratum.
  BigDouble strikePowerAt(int level) {
    final scaled = power.value * BigDouble.fromNum(strikeShareOfRig);
    final own = armPowerAt(level);
    return scaled > own ? scaled : own;
  }

  /// PROVISIONAL price curves, gentle enough that five hundred levels are a
  /// road rather than a wall.
  static BigDouble costOf(ArmPart part, int level) {
    final base = switch (part) {
      ArmPart.bit => 120.0,
      ArmPart.drive => 200.0,
      ArmPart.supply => 150.0,
    };
    final growth = switch (part) {
      ArmPart.bit => 1.12,
      ArmPart.drive => 1.13,
      ArmPart.supply => 1.11,
    };
    return (BigDouble.fromNum(base) *
            BigDouble.fromNum(growth).pow(level.toDouble()))
        .ceil();
  }

  Signal<int> levelOf(ArmPart part) => switch (part) {
    ArmPart.bit => bitLevel,
    ArmPart.drive => driveLevel,
    ArmPart.supply => supplyLevel,
  };

  bool atMaxLevel(ArmPart part) => levelOf(part).value >= maxPartLevel;

  BigDouble upgradeCost(ArmPart part) => costOf(part, levelOf(part).value);

  bool canUpgrade(ArmPart part) =>
      !atMaxLevel(part) && stock.has(ResourceId.regolith, upgradeCost(part));

  /// Buys [levels] of [part], stopping at the cap or at what the store can
  /// pay for -- whichever comes first. Returns how many actually landed.
  int upgrade(ArmPart part, {int levels = 1}) => batch(() {
    final signal = levelOf(part);
    var bought = 0;
    while (bought < levels && signal.value < maxPartLevel) {
      final price = costOf(part, signal.value);
      if (!stock.spend(ResourceId.regolith, price)) break;
      signal.value = signal.value + 1;
      bought++;
    }
    return bought;
  });

  /// How many levels of [part] the store could pay for right now.
  int affordableLevels(ArmPart part) {
    var purse = stock.amount(ResourceId.regolith);
    var level = levelOf(part).value;
    var count = 0;
    while (level < maxPartLevel && count < maxPartLevel) {
      final price = costOf(part, level);
      if (!purse.gteWithTolerance(price)) break;
      purse -= price;
      level++;
      count++;
    }
    return count;
  }

  /// What one strike is expected to bring out of the face: the drop at this
  /// depth times how often the lane pays. A locked ore is worth nothing.
  BigDouble expectedPerStrike(ResourceId id) {
    switch (id) {
      case ResourceId.regolith:
        return _strikeRegolithMean;
      case ResourceId.crystals:
        return crystalDropAt(layer.value) * BigDouble.fromNum(crystalChance);
      case ResourceId.quantonium:
        return quantoniumDropAt(layer.value).big *
            BigDouble.fromNum(strikeQuantoniumChance);
      default:
        for (final row in oreTable) {
          if (row.id != id) continue;
          if (layer.value < row.unlockAt) return BigDouble.zero;
          return oreDropAt(layer.value) * BigDouble.fromNum(row.chance);
        }
        return BigDouble.zero;
    }
  }

  /// What one drill cycle extracts on its OWN, beyond the strike it throws.
  ///
  /// Zero throughout: extraction belongs to strikes alone. The term is kept
  /// because the typed drills land exactly here -- a drill that mines its own
  /// specified resource fills this in and nothing else has to move.
  BigDouble expectedPerCycle(ResourceId id) => BigDouble.zero;

  /// The average yield of one resource per second at the current face.
  ///
  /// Both lanes throw the same strike, so both are counted in strikes: the
  /// hand as fast as energy can pay for one ([energyPerSecond] over
  /// [strikeCost]), the rig once per cycle. Crits, echoes and break payouts
  /// are deliberately left out -- they are bonuses on top, so this reads as
  /// the floor rather than as a promise, and it stays a steady number instead
  /// of one that twitches with luck.
  ///
  /// The two cadences are passed in rather than read here: how often the
  /// engines fire is the app's business, and the core owns no timers.
  BigDouble yieldPerSecond(
    ResourceId id, {
    required double energyPerSecond,
    required double cycleSeconds,
  }) {
    final perStrike = expectedPerStrike(id);
    final byHand = perStrike * BigDouble.fromNum(energyPerSecond / strikeCost);
    if (cycleSeconds <= 0) return byHand;
    final byRig =
        (expectedPerCycle(id) + perStrike) / BigDouble.fromNum(cycleSeconds);
    return byHand + byRig;
  }

  /// One manual blow at the face: spends energy, deals [strikePower], and
  /// takes the loot a strike is worth.
  ///
  /// Extraction belongs to strikes alone. The drill's cycle ends in a strike
  /// of its own, so both lanes roll the same loot table at the same odds,
  /// each on its own streams; the difference between the lanes is who threw
  /// the blow. No crit roll here -- crits are the drill's drama.
  StrikeOutcome strike() => batch(() {
    if (energy.value < strikeCost) return StrikeOutcome.none;
    energy.value = energy.value - strikeCost;

    final rolled = _rollLoot(prefix: 'strike.', multiplier: BigDouble.one);
    final damage = rolled.critical
        ? strikePower * BigDouble.fromNum(strikeCritPower)
        : strikePower;
    final result = _applyDamage(damage);
    return StrikeOutcome(
      spent: strikeCost,
      layersBroken: result.broken,
      thickLayersBroken: result.thickBroken,
      regolithGained: rolled.loot[ResourceId.regolith] ?? BigDouble.zero,
      oresGained: rolled.loot..remove(ResourceId.regolith),
      critical: rolled.critical,
    );
  });

  /// What every strike carries out of the face, whoever struck.
  ///
  /// Regolith always, at the strike share of the cycle formula; ores and
  /// crystals by chance at the table's own odds. Each lane rolls on its own
  /// streams ([prefix]), so manual digging can never shift the drill's
  /// sequence. Quantonium is NOT loot: the anti-brick drip belongs to the
  /// heartbeat.
  ({bool critical, Map<ResourceId, BigDouble> loot}) _rollLoot({
    required String prefix,
    required BigDouble multiplier,
  }) {
    final loot = <ResourceId, BigDouble>{};

    // Measurements, not tonnage -- see [_information].
    var weighted = BigDouble.zero;

    // The one crit in the game. Rolled here so the loot scales in place; the
    // caller reads the flag to scale the blow itself the same way.
    final critical = random
        .stream('${prefix}loot.crit')
        .chance(strikeCritChance);
    if (critical) {
      multiplier = multiplier * BigDouble.fromNum(strikeCritPower);
    }

    // A roll inside the band the loot table promises. The band's ends are
    // upgraded separately, so the roll walks between them rather than around
    // a mean -- one draw either way, so adding the parts shifted no stream.
    final low = strikeRegolithMin;
    final span = strikeRegolithMax - low;
    final spread = random.stream('${prefix}regolith').nextDouble();
    final regolith = (low + span * BigDouble.fromNum(spread)) * multiplier;
    stock.add(ResourceId.regolith, regolith);
    loot[ResourceId.regolith] = regolith;
    weighted += _information(regolith, _strikeRegolithMean, 1);

    for (final row in oreTable) {
      if (layer.value < row.unlockAt) continue;
      if (random.stream('$prefix${row.stream}').chance(row.chance)) {
        final drop = oreDropAt(layer.value) * multiplier;
        stock.add(row.id, drop);
        loot[row.id] = drop;
        weighted += _information(drop, oreDropAt(layer.value), row.chance);
      }
    }

    if (random.stream('${prefix}crystal').chance(crystalChance)) {
      final drop = crystalDropAt(layer.value) * multiplier;
      stock.add(ResourceId.crystals, drop);
      loot[ResourceId.crystals] = drop;
      weighted += _information(drop, crystalDropAt(layer.value), crystalChance);
    }

    // Named apart from the cycle's own anti-brick stream: the loot glint and
    // the heartbeat drip must never share a sequence.
    if (random
        .stream('${prefix}quantonium.loot')
        .chance(strikeQuantoniumChance)) {
      final drop = quantoniumDropAt(layer.value).big * multiplier;
      stock.add(ResourceId.quantonium, drop);
      loot[ResourceId.quantonium] = drop;
      weighted += _information(
        drop,
        quantoniumDropAt(layer.value).big,
        strikeQuantoniumChance,
      );
    }

    _recordData(weighted);
    return (critical: critical, loot: loot);
  }

  CycleOutcome _cycle(int chain) {
    // The cycle is damage plus THE SAME strike a click throws -- same table,
    // same odds, same amounts. The drill has no crit of its own for now: the
    // only crit in the game is the strike's, and it lives inside the loot
    // roll. A drill mining its own specific resource returns with the typed
    // drills.
    final rolled = _rollLoot(prefix: '', multiplier: BigDouble.one);
    final loot = rolled.loot;
    final gained = loot[ResourceId.regolith] ?? BigDouble.zero;
    final crystalsGained = loot[ResourceId.crystals] ?? BigDouble.zero;

    // The anti-brick drip lives in the loot table now: every strike can
    // shake quantonium loose, and the cycle rolls it through its own strike.
    final quantoniumGained = loot.containsKey(ResourceId.quantonium)
        ? quantoniumDropAt(layer.value)
        : 0;

    // The cycle's blow is the rig's power plus the SAME strike a click
    // throws -- a full strike, damage and loot alike, not loot only. One
    // blow, so the structural share is collapsed once, and the crit
    // multiplies the whole of it.
    final blow = power.value + strikePower;
    final struck = _applyDamage(
      rolled.critical ? blow * BigDouble.fromNum(strikeCritPower) : blow,
    );
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
      critical: rolled.critical,
      layersBroken: broken,
      thickLayersBroken: thickBroken,
      echoes: echoes,
    );
  }

  /// Drives [damage] into the face, carrying overflow into deeper layers.
  ({int broken, int thickBroken}) _applyDamage(BigDouble damage) {
    // Every blow also collapses a share of the structure still standing: the
    // fuller the layer, the more there is to shake apart. Deep walls become
    // finite -- the hit count grows with the log of the overmatch -- while a
    // blow that already outmatches the rock barely notices the term.
    var remaining = damage + layerHp.value * BigDouble.fromNum(pierceShare);
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
    // Guaranteed payouts are certain observations, so they enter the data at
    // weight one -- and before the depth moves off the layer they came from.
    var payout = BigDouble.zero;
    if (thick) {
      final bonus = BigDouble.fromNum(thickSpan);
      final regolith = regolithPerCycle.value * bonus;
      final crystals = crystalDropAt(layer.value) * bonus;
      final quantonium = (quantoniumDropAt(layer.value) * thickSpan).big;
      stock.add(ResourceId.regolith, regolith);
      stock.add(ResourceId.crystals, crystals);
      payout +=
          _information(regolith, _strikeRegolithMean, 1) +
          _information(crystals, crystalDropAt(layer.value), 1) +
          _information(quantonium, quantoniumDropAt(layer.value).big, 1);
      for (final row in oreTable) {
        if (layer.value < row.unlockAt) continue;
        final drop = oreDropAt(layer.value) * bonus;
        stock.add(row.id, drop);
        payout += _information(drop, oreDropAt(layer.value), 1);
      }
      stock.add(ResourceId.quantonium, quantonium);
      stock.add(ResourceId.samples, BigDouble.one);
    } else {
      final regolith = regolithPerCycle.value * BigDouble.fromNum(1.5);
      stock.add(ResourceId.regolith, regolith);
      payout = _information(regolith, _strikeRegolithMean, 1);
    }
    _recordData(payout);

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
    'collapses': collapses.value,
    'data': {
      'raw': rawData.value.toJson(),
      'gross': cycleData.value.toJson(),
      'banked': dataBanked.value.toJson(),
      'wallet': dataWallet.value.toJson(),
      'exponent': dataExponentLevel.value,
      'cycleStartMs': cycleStartMs.value,
    },
    'energy': energy.value,
    'arm': {
      'bit': bitLevel.value,
      'drive': driveLevel.value,
      'supply': supplyLevel.value,
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
    collapses.value = _readInt(json['collapses'], 0);
    final data = json['data'];
    if (data is Map) {
      rawData.value = _readBig(data['raw']);
      cycleData.value = _readBig(data['gross']);
      dataBanked.value = _readBig(data['banked']);
      dataWallet.value = _readBig(data['wallet']);
      dataExponentLevel.value = _readInt(data['exponent'], 0);
      cycleStartMs.value = _readInt(data['cycleStartMs'], 0);
    } else {
      rawData.value = BigDouble.zero;
      cycleData.value = BigDouble.zero;
      dataBanked.value = BigDouble.zero;
      dataWallet.value = BigDouble.zero;
      dataExponentLevel.value = 0;
      cycleStartMs.value = 0;
    }
    final arm = json['arm'];
    if (arm is Map) {
      bitLevel.value = _readInt(arm['bit'], 0).clamp(0, maxPartLevel);
      driveLevel.value = _readInt(arm['drive'], 0).clamp(0, maxPartLevel);
      supplyLevel.value = _readInt(arm['supply'], 0).clamp(0, maxPartLevel);
    } else {
      bitLevel.value = 0;
      driveLevel.value = 0;
      supplyLevel.value = 0;
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

  static BigDouble _readBig(Object? value) =>
      value is String ? BigDouble.parse(value) : BigDouble.zero;

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
