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

/// The three tracks every drill carries.
enum DrillPart {
  /// How wide a face the bore covers. Additive on the radius, quadratic on
  /// the area -- the same level is worth more the wider the bore already is.
  radius,

  /// How often it cycles. Multiplicative on the interval, so the track is
  /// finite: it ends where the interval meets the floor.
  drive,

  /// How lucky it is: the odds of a crit and of an echo, bought together.
  calibration,
}

/// Which drill. Each works its own resource; the regolith bore is the one
/// the player starts with.
enum DrillId { regolith, cuprite, ferrite, silicite, crystal }

/// One row of the drill table: what a drill is, before any levels.
class DrillRow {
  const DrillRow(this.id, this.mines, this.label, this.intervalBase);

  final DrillId id;

  /// The one resource this drill brings up.
  final ResourceId mines;

  final String label;

  /// Seconds between cycles before the drive track touches it. A typed drill
  /// starts SLOW on purpose: the drive track's whole lifetime value is
  /// base / floor, so a drill that starts near the floor has nothing to sell.
  final double intervalBase;
}

/// Where one drill stands on its three tracks.
class DrillState {
  DrillState(this.id);

  final DrillId id;

  final Signal<int> radius = Signal(0, name: 'drill radius');
  final Signal<int> drive = Signal(0, name: 'drill drive');
  final Signal<int> calibration = Signal(0, name: 'drill calibration');

  Signal<int> levelOf(DrillPart part) => switch (part) {
    DrillPart.radius => radius,
    DrillPart.drive => drive,
    DrillPart.calibration => calibration,
  };
}

/// One buyer's order: hand over the listed amounts, get paid over list price.
///
/// A plain object rather than signals: a request never changes after it is
/// posted -- it is fulfilled or it expires -- and the list it lives in is
/// redrawn by the clock that expires it.
class TradeRequest {
  TradeRequest({
    required this.needs,
    required this.premium,
    required this.expiresAtMs,
  });

  final List<({ResourceId id, BigDouble amount})> needs;

  /// Paid on top of list price, as a fraction (0.24 reads "премія +24%").
  final double premium;

  /// Wall-clock, like the drift: a courier does not pause with the engines.
  final int expiresAtMs;

  Map<String, Object?> toJson() => {
    'premium': premium,
    'expires': expiresAtMs,
    'needs': {for (final need in needs) need.id.name: need.amount.toJson()},
  };

  static TradeRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final needs = <({ResourceId id, BigDouble amount})>[];
    final raw = json['needs'];
    if (raw is Map) {
      for (final id in ResourceId.values) {
        final amount = raw[id.name];
        if (amount is String) {
          needs.add((id: id, amount: BigDouble.parse(amount)));
        }
      }
    }
    if (needs.isEmpty) return null;
    final premium = json['premium'];
    final expires = json['expires'];
    return TradeRequest(
      needs: needs,
      premium: premium is num ? premium.toDouble() : 0.2,
      expiresAtMs: expires is int ? expires : 0,
    );
  }
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
    // What a Restart pays: this simulation's own haul, compiled. No
    // subtraction against what past restarts banked -- the run is the unit,
    // so each one is paid in full for what it dug.
    bankableData = Computed(() => walletEarned, name: 'bankable data');

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

  /// The generation each part is BUILT to, 0 (Mk I) through 4 (Mk V).
  ///
  /// Deliberately its own number rather than something read off the level: a
  /// part does not grow into the next mark by being levelled, it is rebuilt
  /// into it, and until the player does that the next mark's buffs are not
  /// running and the level cannot pass this mark's ceiling.
  final Signal<int> bitMark = Signal(0, name: 'bit mark');
  final Signal<int> driveMark = Signal(0, name: 'drive mark');
  final Signal<int> supplyMark = Signal(0, name: 'supply mark');

  /// The highest mark each part has EVER been built to, which is a different
  /// thing from where it stands: a restart takes the hardware back, and what
  /// the player learned about it while owning it does not go with it. The
  /// part sheet reads these, so a mark once built stays readable forever.
  final Signal<int> bitPeak = Signal(0, name: 'bit peak');
  final Signal<int> drivePeak = Signal(0, name: 'drive peak');
  final Signal<int> supplyPeak = Signal(0, name: 'supply peak');

  /// Tree levels. Purchasing is not wired up yet; they exist so the formulas
  /// read the way the prototype's do.
  final Signal<int> powerLevel = Signal(0, name: 'power level');
  final Signal<int> enrichmentLevel = Signal(0, name: 'enrichment level');
  final Signal<int> discountLevel = Signal(0, name: 'discount level');
  final Signal<int> quantoniumLevel = Signal(0, name: 'quantonium level');

  /// Raw data of the current simulation. Feeds the collapse gate; a restart
  /// resets it.
  /// What this simulation has dug up and not yet compiled.
  ///
  /// A view on the registry rather than a field of its own: it is a mined
  /// resource like the ores, so the warehouse, the strip, the loot table and
  /// the offline window all carry it without being told about it, and a
  /// Restart wipes it with everything else mined.
  Signal<BigDouble> get rawData => stock.signal(ResourceId.rawData);

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
  /// How well the centre compiles. Each level lifts the rate; the JSON key
  /// is still 'exponent' from when compilation was a power, and renaming it
  /// would cost a migration for a number nobody has spent yet.
  final Signal<int> compilerLevel = Signal(0, name: 'compiler level');

  /// Collapses performed, ever.
  final Signal<int> collapses = Signal(0, name: 'collapses');

  /// How many racks the centre can actually use, 1 to [maxPendingCollapses].
  ///
  /// Starts at one. Holding five collapses at once is capacity the player
  /// buys, not something the wall comes with: the whole decision the wall
  /// exists for -- take one now or wait for more -- has to be earned before
  /// it can be made.
  final Signal<int> servers = Signal(1, name: 'servers');

  int get unlockedServers =>
      servers.value.clamp(1, maxPendingCollapses).toInt();

  /// Wall-clock epoch ms the cycle began, for the drift formula. Zero means
  /// not stamped yet: the app stamps it, keeping DateTime out of the core.
  /// When this cycle began, on the ACKNOWLEDGED clock ([seenNow] units,
  /// not epoch ms). -1 until the app stamps it.
  final Signal<int> cycleStartMs = Signal(-1, name: 'cycle start');

  /// The longest absence the game acknowledges in one gap: away for a week,
  /// paid and drifted as if away for two days. One constant for EVERY
  /// wall-clock mechanic, so none of them can quietly disagree.
  static const int absenceCapMs = 48 * 60 * 60 * 1000;

  /// Wall time the game has acknowledged, in ms. Advances by real gaps,
  /// each clamped to [absenceCapMs].
  int wallSeenMs = 0;

  /// The raw wall stamp of the last [observeWall]. Zero = never observed;
  /// the first observation banks nothing, so the epoch offset never leaks
  /// into the acknowledged total.
  int lastWallMs = 0;

  /// What the acknowledged clock reads at [nowMs], WITHOUT banking it.
  /// Continuous between observations; a gap longer than the cap contributes
  /// exactly the cap, and a clock wound backwards contributes nothing.
  int seenNow(int nowMs) {
    if (lastWallMs == 0) return wallSeenMs;
    final gap = nowMs - lastWallMs;
    if (gap <= 0) return wallSeenMs;
    return wallSeenMs + (gap > absenceCapMs ? absenceCapMs : gap);
  }

  /// Banks the clock up to [nowMs]. The app calls this every batch and on
  /// every return from absence; between calls [seenNow] extrapolates.
  ///
  /// MONOTONIC: a rewound wall clock banks nothing and, crucially, does not
  /// move [lastWallMs] backwards -- that stamp is the breach detector's
  /// evidence, and letting a rewound clock overwrite it would pardon the
  /// very tampering it proves.
  void observeWall(int nowMs) {
    if (nowMs <= lastWallMs) return;
    wallSeenMs = seenNow(nowMs);
    lastWallMs = nowMs;
  }

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

  double get echoChance => drillEchoChance(DrillId.regolith);

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
  /// How much substrate one cube is compiled from.
  ///
  /// A plain divisor, not a power. A sublinear curve made splitting a haul
  /// across many short runs pay more than one long one -- n runs of x/n came
  /// to n^0.75 times a single run of x -- so the optimum was to restart as
  /// often as the gate allowed. Dividing is neutral: the same substrate
  /// compiles to the same cubes however many restarts it took, and WHEN to
  /// restart goes back to being a question about when you want to spend.
  static const double rawPerCube = 1000;

  /// What one compiler level adds to the rate.
  static const double compilerStep = 0.05;

  /// The oversaturation gate: one run's raw data reaching this allows a
  /// collapse. Sized against the accrual below so a first collapse is days
  /// of play, not minutes. PROVISIONAL.
  // Recalibrated when data stopped being a computed measurement and became
  // a dug resource: the old 3e8 was denominated in normalised sightings,
  // which no longer exist. PROVISIONAL -- tune against tool/data_pace.
  /// What ONE collapse costs, in cubes.
  ///
  /// Cubes rather than the raw substrate behind them, so the collapse gauge
  /// and the restart preview read the same figure. Consequence to keep in
  /// view: the compiler upgrade lifts cubes, so it brings the collapse nearer
  /// as well as paying more -- one lever, two effects.
  static final BigDouble collapseThresholdBase = BigDouble.fromNum(1.5e5);

  /// How many collapses the centre can hold at once -- one per rack.
  ///
  /// The wall is the decision: one full rack already lets the player collapse,
  /// and every rack they wait for is another collapse point banked in the
  /// same act. Past the fifth there is nowhere to put the cubes, so leaving
  /// it full is a real loss rather than a safe idle.
  static const int maxPendingCollapses = 5;

  /// What each rack costs over the one before it.
  ///
  /// The costs are CUMULATIVE totals, not prices paid one after another: the
  /// first rack is full at the base, the second at base x2.6, the third at
  /// base x2.6^2. So a run worth twice the base fills the first rack and
  /// makes a start on the second, and one worth five times fills two.
  /// PROVISIONAL.
  static const double collapseRackGrowth = 2.6;

  /// What the gate is multiplied by per collapse already performed. Later
  /// cycles reach far deeper far sooner, and data accrues with depth, so a
  /// fixed gate would fall in hours by the fifth cycle. PROVISIONAL.
  static const double collapseThresholdGrowth = 4;

  /// Drift: the collapse threshold melts by this factor per wall-clock day,
  /// online and offline alike.
  static const double collapseDriftPerDay = 0.97;

  /// How many days of drift a cycle accrues before the melt stops.
  ///
  /// Capped rather than endless (decision 2026-08-29). At 30 days the wall
  /// stands at 0.97^30 = 40% of base -- a relief of x2.5, which is still less
  /// than the x4 a single collapse adds, so waiting can never outrun the
  /// ladder. Uncapped it eventually could, and a player who leaves for a
  /// season would come back to a gate that had melted to nothing.
  static const double collapseDriftCapDays = 30;

  int get simulationNumber => restarts.value + 1;

  /// Cycles CLOSED, not the ordinal of the one being played. A fresh save
  /// has none: the first cycle exists once the first rack fills and the
  /// player collapses it.
  int get cycleNumber => collapses.value;

  /// How many collapses are ready to be taken right now, 0 to
  /// [maxPendingCollapses]. Each is worth a collapse point and closes a
  /// cycle, so taking three at once is three of both.
  int pendingCollapses(int nowMs) {
    var full = 0;
    for (var rack = 0; rack < unlockedServers; rack++) {
      if (!walletEarned.gteWithTolerance(collapseCost(rack, nowMs))) break;
      full++;
    }
    return full;
  }

  /// The cubes at which [rack] (0-based) is full -- a running total, so rack 2
  /// being full means rack 0 and rack 1 are too.
  BigDouble collapseCost(int rack, int nowMs) =>
      collapseThreshold(nowMs) *
      BigDouble.fromNum(math.pow(collapseRackGrowth, rack).toDouble());

  /// How full one rack is, 0 to 1. A rack fills from where the one before it
  /// finished, so the wall reads left to right without gaps.
  double rackFill(int rack, int nowMs) {
    final to = collapseCost(rack, nowMs);
    final from = rack == 0 ? BigDouble.zero : collapseCost(rack - 1, nowMs);
    final span = to - from;
    if (span <= BigDouble.zero) return 0;
    return ((walletEarned - from) / span).toDouble().clamp(0.0, 1.0);
  }

  /// Cubes per unit of substrate, before the divisor.
  double get compileRate => 1 + compilerStep * compilerLevel.value;

  /// What the current simulation would compile into.
  ///
  /// This run's substrate divided by [rawPerCube], not raised to a power.
  /// A sublinear curve would pay more for splitting one haul across many
  /// short runs than for one long one, and per-run banking would turn
  /// into restart-spam; a division is neutral, so the same substrate is
  /// worth the same cubes however many restarts it took to dig.
  BigDouble get walletEarned =>
      rawData.value * BigDouble.fromNum(compileRate / rawPerCube);

  /// The collapse threshold at [nowMs], melted by drift since the cycle
  /// began -- on the acknowledged clock, see [driftDays].
  BigDouble collapseThreshold(int nowMs) {
    final base =
        collapseThresholdBase *
        BigDouble.fromNum(collapseThresholdGrowth)
            .pow(collapses.value.toDouble());
    final days = driftDays(nowMs);
    if (days <= 0) return base;
    return base *
        BigDouble.fromNum(math.pow(collapseDriftPerDay, days).toDouble());
  }

  /// Days of drift this cycle has banked, capped at [collapseDriftCapDays].
  ///
  /// Measured on the ACKNOWLEDGED clock, so an absence past [absenceCapMs]
  /// melts the gate by two days, not by however long the player was gone.
  /// A negative start means the app has not stamped the cycle yet.
  double driftDays(int nowMs) {
    final start = cycleStartMs.value;
    if (start < 0) return 0;
    final seen = seenNow(nowMs);
    if (seen <= start) return 0;
    final days = (seen - start) / Duration.millisecondsPerDay;
    return days > collapseDriftCapDays ? collapseDriftCapDays : days;
  }

  /// How far through the drift window the cycle is, 0 to 1.
  double driftProgress(int nowMs) => driftDays(nowMs) / collapseDriftCapDays;

  /// How much of the gate the drift has already eaten, 0 to 1. What the wall
  /// is worth now is (1 - this) of what it was worth on day zero.
  double driftDiscount(int nowMs) =>
      1 - math.pow(collapseDriftPerDay, driftDays(nowMs)).toDouble();

  /// Whether one run's raw data has oversaturated the simulation.
  bool collapseReady(int nowMs) => pendingCollapses(nowMs) >= 1;

  /// One haul as MEASUREMENTS rather than as tonnes: how many typical drops
  /// of its kind this is, over how often a drop of that kind is seen.
  ///
  /// Books a haul of substrate: into the store like any resource, and into
  /// the cycle's running total, which is what the wallet is compressed from.
  ///
  /// The cycle total is kept apart because it must survive a Restart: the
  /// store is wiped, the record of what this CYCLE has produced is not.
  void _recordData(BigDouble gained) {
    if (gained.isZero) return;
    stock.add(ResourceId.rawData, gained);
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

    batch(() {
      for (final entry in gained.entries) {
        // Substrate is a lane like any other now, so an absence earns it by
        // the same expectation -- and the cycle's running total has to hear
        // about it, which plain stocking would not do.
        if (entry.key == ResourceId.rawData) {
          _recordData(entry.value);
          continue;
        }
        stock.add(entry.key, entry.value);
      }
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
  /// How often a strike turns up a fragment of the substrate.
  ///
  /// Small but not microscopic. The collapse gate is the one wall in the
  /// game, so it must not wobble: at these odds a session throws thousands
  /// of strikes and the law of large numbers flattens the variance to a few
  /// percent. At a tenth of this it would be a lottery.
  static const double rawDataChance = 0.02;

  /// How much one fragment is worth.
  ///
  /// DELIBERATELY not the ore curve. Drop volumes inflate exponentially with
  /// depth (regolith alone is 1.03^m), and a data lane that inherited that
  /// would make one strike at 400 m worth thousands at the surface -- which
  /// is exactly how the fixed collapse gate once fell in minutes. Deeper rock
  /// holds denser substrate, but linearly.
  static BigDouble rawDataDropAt(int layer) =>
      BigDouble.fromNum(1 + layer / 25);

  static const double strikeCritChance = 0.05;
  static const double strikeCritPower = 1.20;

  // ------------------------------------------------------------ drills
  //
  // A drill is a bore of some RADIUS working the face on its own CYCLE.
  // What it brings up is what its blow brings up, scaled by how much face
  // it covers -- one loot table, one truth, a wider sweep.

  /// The bore every drill starts with, in metres.
  static const double drillRadiusBase = 5;

  /// What one level of the radius track adds. Additive on the RADIUS, so
  /// the area it buys grows as pi(2r+1) -- the same level is worth more the
  /// wider the bore already is, which is the whole point of the track.
  static const double drillRadiusPerLevel = 1;

  /// What one level of the drive track cuts off the CURRENT interval. The
  /// track is finite: it ends where the interval meets [drillIntervalFloor],
  /// and its whole lifetime value is base / floor whatever this number is --
  /// the percentage only sets how many levels that value is spread over.
  static const double drillSpeedStep = 0.01;

  /// No drill cycles faster than this. A floor rather than an asymptote, so
  /// the timer can never outrun the frame.
  static const double drillIntervalFloor = 2;

  /// The calibration track: one number buying both odds.
  static const double drillCritBase = 0.05;
  static const double drillCritPerLevel = 0.002;
  static const double drillCritPower = 1.20;
  static const double drillEchoBase = 0.01;
  static const double drillEchoPerLevel = 0.0005;

  /// Every drill in the game, in the order they open.
  ///
  /// A table rather than a branch per drill: a new drill is a row here plus
  /// its resource, not a new field threaded through every place that counts.
  static const List<DrillRow> drillTable = [
    DrillRow(DrillId.regolith, ResourceId.regolith, 'Реголітовий', 4),
    DrillRow(DrillId.cuprite, ResourceId.cuprite, 'Купритовий', 100),
    DrillRow(DrillId.ferrite, ResourceId.ferrite, 'Феритовий', 100),
    DrillRow(DrillId.silicite, ResourceId.silicite, 'Силіцитовий', 100),
    DrillRow(DrillId.crystal, ResourceId.crystals, 'Кристалічний', 100),
  ];

  static DrillRow rowFor(DrillId id) =>
      drillTable.firstWhere((row) => row.id == id);

  /// The levels each drill carries. Only the regolith drill is owned for
  /// now; the rest wait on the restart tree.
  final Map<DrillId, DrillState> drillState = {
    for (final row in drillTable) row.id: DrillState(row.id),
  };

  DrillState drill(DrillId id) => drillState[id]!;

  bool drillOwned(DrillId id) => id == DrillId.regolith;

  /// The bore, in metres.
  double drillRadius(DrillId id) =>
      drillRadiusBase + drillRadiusPerLevel * drill(id).radius.value;

  /// The face it covers, in square metres.
  double drillArea(DrillId id) {
    final r = drillRadius(id);
    return math.pi * r * r;
  }

  /// How much more face than a fresh bore -- and so how much more its blow
  /// brings up. Exactly 1 at level 0, which is what makes wiring it safe.
  BigDouble drillYieldScale(DrillId id) => BigDouble.fromNum(
    drillArea(id) / (math.pi * drillRadiusBase * drillRadiusBase),
  );

  /// Seconds between cycles, never below the floor.
  double drillInterval(DrillId id) {
    final base = rowFor(id).intervalBase;
    final cut = math.pow(1 - drillSpeedStep, drill(id).drive.value).toDouble();
    final interval = base * cut;
    return interval < drillIntervalFloor ? drillIntervalFloor : interval;
  }

  /// The last drive level that still buys anything.
  ///
  /// Sold levels past this would cost real resources for nothing, so the
  /// track simply ends here instead of clamping in silence.
  static int drillDriveCap(DrillId id) {
    final base = rowFor(id).intervalBase;
    if (base <= drillIntervalFloor) return 0;
    final n =
        math.log(drillIntervalFloor / base) / math.log(1 - drillSpeedStep);
    return n.ceil();
  }

  double drillCritChance(DrillId id) =>
      drillCritBase + drillCritPerLevel * drill(id).calibration.value;

  double drillEchoChance(DrillId id) =>
      drillEchoBase + drillEchoPerLevel * drill(id).calibration.value;

  static BigDouble drillCostOf(DrillPart part, int level) {
    final base = switch (part) {
      DrillPart.radius => 400.0,
      DrillPart.drive => 900.0,
      DrillPart.calibration => 2500.0,
    };
    final growth = switch (part) {
      DrillPart.radius => 1.15,
      DrillPart.drive => 1.17,
      DrillPart.calibration => 1.22,
    };
    return (BigDouble.fromNum(base) *
            BigDouble.fromNum(growth).pow(level.toDouble()))
        .floor();
  }

  BigDouble drillUpgradeCost(DrillId id, DrillPart part) =>
      drillCostOf(part, drill(id).levelOf(part).value);

  /// Where a track stops. Radius and calibration run on; the drive track is
  /// finite by construction.
  int drillCap(DrillId id, DrillPart part) =>
      part == DrillPart.drive ? drillDriveCap(id) : 1 << 30;

  bool drillAtCap(DrillId id, DrillPart part) =>
      drill(id).levelOf(part).value >= drillCap(id, part);

  bool canUpgradeDrill(DrillId id, DrillPart part) =>
      drillOwned(id) &&
      !drillAtCap(id, part) &&
      stock.has(ResourceId.regolith, drillUpgradeCost(id, part));

  int upgradeDrill(DrillId id, DrillPart part, {int levels = 1}) => batch(() {
    if (!drillOwned(id)) return 0;
    final signal = drill(id).levelOf(part);
    final cap = drillCap(id, part);
    var bought = 0;
    while (bought < levels && signal.value < cap) {
      if (!stock.spend(ResourceId.regolith, drillCostOf(part, signal.value))) {
        break;
      }
      signal.value = signal.value + 1;
      bought++;
    }
    return bought;
  });

  int affordableDrillLevels(DrillId id, DrillPart part) {
    var purse = stock.amount(ResourceId.regolith);
    var level = drill(id).levelOf(part).value;
    final cap = drillCap(id, part);
    var count = 0;
    while (level < cap && count < 1000) {
      final price = drillCostOf(part, level);
      if (purse < price) break;
      purse -= price;
      level++;
      count++;
    }
    return count;
  }

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

  Signal<int> markOf(ArmPart part) => switch (part) {
    ArmPart.bit => bitMark,
    ArmPart.drive => driveMark,
    ArmPart.supply => supplyMark,
  };

  Signal<int> peakOf(ArmPart part) => switch (part) {
    ArmPart.bit => bitPeak,
    ArmPart.drive => drivePeak,
    ArmPart.supply => supplyPeak,
  };

  /// The best mark of [part] the player has ever built, from 0 (Mk I).
  int knownGeneration(ArmPart part) => peakOf(part).value;

  static const int lastMark = maxPartLevel ~/ levelsPerGeneration - 1;

  /// As far as [part] can be levelled before it has to be rebuilt.
  int ceilingOf(ArmPart part) => (markOf(part).value + 1) * levelsPerGeneration;

  bool atMarkCeiling(ArmPart part) => levelOf(part).value >= ceilingOf(part);

  /// A part at its ceiling with a mark left to build is ready to evolve.
  bool canEvolve(ArmPart part) =>
      atMarkCeiling(part) && markOf(part).value < lastMark;

  /// Rebuilds [part] into its next mark. Returns the mark it now carries, or
  /// null when it was not ready -- the caller has nothing to celebrate then.
  int? evolve(ArmPart part) => batch(() {
    if (!canEvolve(part)) return null;
    final mark = markOf(part);
    mark.value = mark.value + 1;
    final peak = peakOf(part);
    if (mark.value > peak.value) peak.value = mark.value;
    return mark.value;
  });

  bool atMaxLevel(ArmPart part) =>
      levelOf(part).value >= maxPartLevel && markOf(part).value >= lastMark;

  BigDouble upgradeCost(ArmPart part) => costOf(part, levelOf(part).value);

  bool canUpgrade(ArmPart part) =>
      !atMarkCeiling(part) && stock.has(ResourceId.regolith, upgradeCost(part));

  /// Buys [levels] of [part], stopping at the cap or at what the store can
  /// pay for -- whichever comes first. Returns how many actually landed.
  int upgrade(ArmPart part, {int levels = 1}) => batch(() {
    final signal = levelOf(part);
    final ceiling = ceilingOf(part);
    var bought = 0;
    while (bought < levels && signal.value < ceiling) {
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
    final ceiling = ceilingOf(part);
    var count = 0;
    while (level < ceiling && count < maxPartLevel) {
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
      case ResourceId.rawData:
        return rawDataDropAt(layer.value) * BigDouble.fromNum(rawDataChance);
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
    double? critChance,
  }) {
    final loot = <ResourceId, BigDouble>{};

    // The one crit in the game. Rolled here so the loot scales in place; the
    // caller reads the flag to scale the blow itself the same way.
    final critical = random
        .stream('${prefix}loot.crit')
        .chance(critChance ?? strikeCritChance);
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

    for (final row in oreTable) {
      if (layer.value < row.unlockAt) continue;
      if (random.stream('$prefix${row.stream}').chance(row.chance)) {
        final drop = oreDropAt(layer.value) * multiplier;
        stock.add(row.id, drop);
        loot[row.id] = drop;
      }
    }

    if (random.stream('${prefix}crystal').chance(crystalChance)) {
      final drop = crystalDropAt(layer.value) * multiplier;
      stock.add(ResourceId.crystals, drop);
      loot[ResourceId.crystals] = drop;
    }

    // Named apart from the cycle's own anti-brick stream: the loot glint and
    // the heartbeat drip must never share a sequence.
    if (random
        .stream('${prefix}quantonium.loot')
        .chance(strikeQuantoniumChance)) {
      final drop = quantoniumDropAt(layer.value).big * multiplier;
      stock.add(ResourceId.quantonium, drop);
      loot[ResourceId.quantonium] = drop;
    }

    // The substrate lane. Its own stream, named apart from everything else,
    // so adding it shifted no roll that came before it.
    if (random.stream('${prefix}rawdata').chance(rawDataChance)) {
      final drop = rawDataDropAt(layer.value) * multiplier;
      _recordData(drop);
      loot[ResourceId.rawData] = drop;
    }

    return (critical: critical, loot: loot);
  }

  CycleOutcome _cycle(int chain) {
    // The cycle is damage plus THE SAME strike a click throws -- same table,
    // same odds, same amounts. The drill has no crit of its own for now: the
    // only crit in the game is the strike's, and it lives inside the loot
    // roll. A drill mining its own specific resource returns with the typed
    // drills.
    // The blow is the same blow; the AREA it covers is what the radius
    // track buys, so the one loot roll is scaled rather than a second
    // source added beside it.
    final rolled = _rollLoot(
      prefix: '',
      multiplier: drillYieldScale(DrillId.regolith),
      critChance: drillCritChance(DrillId.regolith),
    );
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
      // A thick break opens three metres of face at once, so the substrate
      // it exposes is certain rather than rolled.
      payout = rawDataDropAt(layer.value) * BigDouble.fromNum(thickSpan);
      final bonus = BigDouble.fromNum(thickSpan);
      final regolith = regolithPerCycle.value * bonus;
      final crystals = crystalDropAt(layer.value) * bonus;
      final quantonium = (quantoniumDropAt(layer.value) * thickSpan).big;
      stock.add(ResourceId.regolith, regolith);
      stock.add(ResourceId.crystals, crystals);
      for (final row in oreTable) {
        if (layer.value < row.unlockAt) continue;
        stock.add(row.id, oreDropAt(layer.value) * bonus);
      }
      stock.add(ResourceId.quantonium, quantonium);
      stock.add(ResourceId.samples, BigDouble.one);
    } else {
      stock.add(
        ResourceId.regolith,
        regolithPerCycle.value * BigDouble.fromNum(1.5),
      );
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

  // -------------------------------------------------------------- trade

  /// The price list. Fixed by design: no depth scaling, no market swings --
  /// a pile of regolith is worth the same credits whenever it is sold, so
  /// "when to sell" is about what the player needs, never about timing.
  /// PROVISIONAL numbers, like every other constant here.
  static const List<({ResourceId id, double price})> priceTable = [
    (id: ResourceId.regolith, price: 0.4),
    (id: ResourceId.cuprite, price: 820),
    (id: ResourceId.ferrite, price: 1400),
    (id: ResourceId.silicite, price: 2900),
    (id: ResourceId.crystals, price: 12),
  ];

  /// The shares a position can sell at. Steps rather than a free slider:
  /// four honest notches read at a glance, and the setting survives being
  /// toggled off without inventing a fifth "0%" state.
  static const List<int> sellShares = [25, 50, 75, 100];

  final Map<ResourceId, Signal<bool>> _selling = {
    for (final row in priceTable)
      row.id: Signal(true, name: 'selling ${row.id.name}'),
  };

  final Map<ResourceId, Signal<int>> _sellShare = {
    for (final row in priceTable)
      row.id: Signal(100, name: 'sell share ${row.id.name}'),
  };

  /// Whether "sell everything" takes this position. An off position keeps
  /// its colour, its share and its own sell button -- the toggle means one
  /// thing only.
  Signal<bool> sellingOf(ResourceId id) => _selling[id]!;

  /// The whole shelf's switch, INDEPENDENT of the positions' own: turning
  /// the group off does not rewrite what each position chose, so turning it
  /// back on restores the exact picture the player had set up.
  final Signal<bool> sellingResources = Signal(true, name: 'selling group');

  /// Whether "sell everything" takes [id] right now: its own switch AND the
  /// shelf's.
  bool sellsInSweep(ResourceId id) =>
      sellingResources.value && _selling[id]!.value;

  /// What share of the held amount a sale moves, in percent.
  Signal<int> sellShareOf(ResourceId id) => _sellShare[id]!;

  BigDouble sellPrice(ResourceId id) =>
      BigDouble.fromNum(priceTable.firstWhere((row) => row.id == id).price);

  /// The amount one manual sale of [id] would move right now.
  BigDouble sellLot(ResourceId id) =>
      stock.amount(id) * BigDouble.fromNum(_sellShare[id]!.value / 100);

  /// What one manual sale of [id] pays right now.
  BigDouble sellYield(ResourceId id) => sellLot(id) * sellPrice(id);

  /// What "sell everything" pays: only positions left switched on. The
  /// button quotes this same number, so it can never surprise.
  BigDouble sellAllYield() {
    var sum = BigDouble.zero;
    for (final row in priceTable) {
      if (sellsInSweep(row.id)) sum += sellYield(row.id);
    }
    return sum;
  }

  /// Sells [id] at its share, toggle or no toggle: the per-position button
  /// is a manual override, and a manual act obeys the finger, not the flag.
  BigDouble sellPosition(ResourceId id) {
    final lot = sellLot(id);
    if (lot.isZero) return BigDouble.zero;
    final paid = lot * sellPrice(id);
    batch(() {
      stock.spend(id, lot);
      stock.add(ResourceId.credits, paid);
    });
    return paid;
  }

  /// Sells every position that is switched on. Returns the credits paid.
  BigDouble sellAll() {
    var paid = BigDouble.zero;
    batch(() {
      for (final row in priceTable) {
        if (sellsInSweep(row.id)) paid += sellPosition(row.id);
      }
    });
    return paid;
  }

  // ------------------------------------------------------------- requests

  /// How many requests can wait at once. A future tree node raises it.
  int get requestSlots => 3;

  /// How often a new request arrives, wall-clock. PROVISIONAL.
  static const int requestIntervalMs = 10 * 60 * 1000;

  /// How long a request waits before leaving. Expiry costs nothing: the
  /// premium is a bonus on top of list price, never a gate (safeguard 4).
  static const int requestLifetimeMs = 12 * 60 * 1000;

  static const double requestShareFloor = 0.15;
  static const double requestShareCeil = 0.45;
  static const double requestPremiumFloor = 0.15;
  static const double requestPremiumCeil = 0.40;
  static const double requestSecondLineChance = 0.45;

  /// The requests on the board, oldest first. Mutated only by
  /// [syncRequests] and [fulfilRequest]; redraws ride the app's own clock.
  final List<TradeRequest> requests = [];

  /// When the next courier is due. Zero means the board has never been
  /// looked at -- the first sync posts a request immediately, so the tab is
  /// never empty on first visit.
  int nextRequestAtMs = 0;

  /// Retires the expired, posts the due. Wall-clock like the drift, and for
  /// the same reason: couriers do not pause with the engines. A long absence
  /// posts at most a boardful -- the backlog is not replayed one by one.
  void syncRequests(int nowMs) {
    requests.removeWhere((request) => request.expiresAtMs <= nowMs);
    if (nextRequestAtMs == 0) nextRequestAtMs = nowMs;
    while (nextRequestAtMs <= nowMs) {
      if (requests.length >= requestSlots || !_spawnRequest(nowMs)) {
        // The board is full, or there is nothing to ask for yet: the next
        // courier comes a full interval from NOW, not the moment a slot
        // frees -- a freed slot is not a delivery.
        nextRequestAtMs = nowMs + requestIntervalMs;
        break;
      }
      nextRequestAtMs += requestIntervalMs;
    }
  }

  bool _spawnRequest(int nowMs) {
    // Only what the player actually holds is asked for: a request for an ore
    // the run has never seen would be a wall, and the amounts are shares of
    // the pile so they scale with progress by construction.
    final pool = [
      for (final row in priceTable)
        if (!stock.amount(row.id).isZero) row.id,
    ];
    if (pool.isEmpty) return false;
    final roll = random.stream('trade.request');
    final lines = pool.length > 1 && roll.chance(requestSecondLineChance)
        ? 2
        : 1;
    final needs = <({ResourceId id, BigDouble amount})>[];
    for (var line = 0; line < lines; line++) {
      final id = pool.removeAt(roll.nextInt(pool.length));
      final share =
          requestShareFloor +
          (requestShareCeil - requestShareFloor) * roll.nextDouble();
      needs.add((id: id, amount: stock.amount(id) * BigDouble.fromNum(share)));
    }
    final premium =
        requestPremiumFloor +
        (requestPremiumCeil - requestPremiumFloor) * roll.nextDouble();
    requests.add(
      TradeRequest(
        needs: needs,
        premium: premium,
        expiresAtMs: nowMs + requestLifetimeMs,
      ),
    );
    return true;
  }

  /// List price of everything the request wants, plus its premium.
  BigDouble requestPayout(TradeRequest request) {
    var sum = BigDouble.zero;
    for (final need in request.needs) {
      sum += need.amount * sellPrice(need.id);
    }
    return sum * BigDouble.fromNum(1 + request.premium);
  }

  bool canFulfil(TradeRequest request) =>
      request.needs.every((need) => stock.has(need.id, need.amount));

  bool fulfilRequest(TradeRequest request) {
    if (!requests.contains(request) || !canFulfil(request)) return false;
    batch(() {
      for (final need in request.needs) {
        stock.spend(need.id, need.amount);
      }
      stock.add(ResourceId.credits, requestPayout(request));
    });
    requests.remove(request);
    return true;
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
    'servers': servers.value,
    'data': {
      'raw': rawData.value.toJson(),
      'gross': cycleData.value.toJson(),
      'banked': dataBanked.value.toJson(),
      'wallet': dataWallet.value.toJson(),
      'exponent': compilerLevel.value,
      'cycleStartSeen': cycleStartMs.value,
    },
    'energy': energy.value,
    'bores': {
      for (final row in drillTable)
        row.id.name: {
          'radius': drill(row.id).radius.value,
          'drive': drill(row.id).drive.value,
          'calibration': drill(row.id).calibration.value,
        },
    },
    'arm': {
      'bit': bitLevel.value,
      'drive': driveLevel.value,
      'supply': supplyLevel.value,
      'bitMark': bitMark.value,
      'driveMark': driveMark.value,
      'supplyMark': supplyMark.value,
      'bitPeak': bitPeak.value,
      'drivePeak': drivePeak.value,
      'supplyPeak': supplyPeak.value,
    },
    'tree': {
      'power': powerLevel.value,
      'enrichment': enrichmentLevel.value,
      'discount': discountLevel.value,
      'quantonium': quantoniumLevel.value,
    },
    'stock': stock.toJson(),
    'clock': {'seen': wallSeenMs, 'last': lastWallMs},
    'trade': {
      // Only departures from the defaults are written: a fresh build reads
      // an old save and every position simply sells whole, switched on.
      'off': [
        for (final row in priceTable)
          if (!_selling[row.id]!.value) row.id.name,
      ],
      if (!sellingResources.value) 'groupOff': true,
      'share': {
        for (final row in priceTable)
          if (_sellShare[row.id]!.value != 100)
            row.id.name: _sellShare[row.id]!.value,
      },
      'nextAt': nextRequestAtMs,
      'requests': [for (final request in requests) request.toJson()],
    },
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
    servers.value = _readInt(json['servers'], 1).clamp(1, maxPendingCollapses);
    final data = json['data'];
    if (data is Map) {
      rawData.value = _readBig(data['raw']);
      cycleData.value = _readBig(data['gross']);
      dataBanked.value = _readBig(data['banked']);
      dataWallet.value = _readBig(data['wallet']);
      compilerLevel.value = _readInt(data['exponent'], 0);
      // Older saves stamped the cycle in EPOCH ms under 'cycleStartMs'; the
      // acknowledged clock cannot honour that unit, so their drift restarts
      // once rather than being misread as decades of melt.
      cycleStartMs.value = _readInt(data['cycleStartSeen'], -1);
    } else {
      rawData.value = BigDouble.zero;
      cycleData.value = BigDouble.zero;
      dataBanked.value = BigDouble.zero;
      dataWallet.value = BigDouble.zero;
      compilerLevel.value = 0;
      cycleStartMs.value = -1;
    }
    final bores = json['bores'];
    for (final row in drillTable) {
      final held = bores is Map ? bores[row.id.name] : null;
      final state = drill(row.id);
      for (final part in DrillPart.values) {
        final stored = held is Map ? _readInt(held[part.name], 0) : 0;
        state.levelOf(part).value = stored.clamp(0, drillCap(row.id, part));
      }
    }
    final arm = json['arm'];
    if (arm is Map) {
      bitLevel.value = _readInt(arm['bit'], 0).clamp(0, maxPartLevel);
      driveLevel.value = _readInt(arm['drive'], 0).clamp(0, maxPartLevel);
      supplyLevel.value = _readInt(arm['supply'], 0).clamp(0, maxPartLevel);
      // A save from before the marks were kept knows only where the parts
      // stand, and standing at a level is proof enough of having been built
      // that far -- demoting a returning player would be the worse lie.
      for (final part in ArmPart.values) {
        final level = levelOf(part).value;
        final built = generationOf(level);
        final mark = _readInt(
          arm['${part.name}Mark'],
          built,
        ).clamp(0, lastMark);
        markOf(part).value = mark > built ? mark : built;
        // A peak above the last mark cannot be a mark: it is a level,
        // written by a build that kept peaks in levels. Convert rather than
        // clamp -- clamping turned every such save into "Mk V already seen".
        final stored = _readInt(arm['${part.name}Peak'], markOf(part).value);
        final seen = (stored > lastMark ? generationOf(stored) : stored).clamp(
          0,
          lastMark,
        );
        peakOf(part).value = seen > markOf(part).value
            ? seen
            : markOf(part).value;
      }
    } else {
      for (final part in ArmPart.values) {
        levelOf(part).value = 0;
        markOf(part).value = 0;
        peakOf(part).value = 0;
      }
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

    final clock = json['clock'];
    if (clock is Map) {
      wallSeenMs = _readInt(clock['seen'], 0);
      lastWallMs = _readInt(clock['last'], 0);
    } else {
      wallSeenMs = 0;
      lastWallMs = 0;
    }

    final trade = json['trade'];
    requests.clear();
    if (trade is Map) {
      final off = trade['off'];
      final share = trade['share'];
      for (final row in priceTable) {
        _selling[row.id]!.value = off is! List || !off.contains(row.id.name);
        final stored = share is Map ? share[row.id.name] : null;
        _sellShare[row.id]!.value = sellShares.contains(stored)
            ? stored as int
            : 100;
      }
      sellingResources.value = trade['groupOff'] != true;
      nextRequestAtMs = _readInt(trade['nextAt'], 0);
      final posted = trade['requests'];
      if (posted is List) {
        for (final entry in posted) {
          final request = TradeRequest.fromJson(entry);
          if (request != null) requests.add(request);
        }
      }
    } else {
      for (final row in priceTable) {
        _selling[row.id]!.value = true;
        _sellShare[row.id]!.value = 100;
      }
      sellingResources.value = true;
      nextRequestAtMs = 0;
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
