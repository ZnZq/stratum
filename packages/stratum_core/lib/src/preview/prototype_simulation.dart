import 'dart:math' as math;

import '../big_double.dart';
import '../random_source.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'arm_part.dart';
import 'craft_line.dart';
import 'acknowledged_clock.dart';
import 'arm_tracks.dart';
import 'auto_buyer.dart';
import 'auto_crafter.dart';
import 'auto_fulfil.dart';
import 'auto_seller.dart';
import 'auto_strike.dart';
import 'automations.dart';
import 'collapse_ledger.dart';
import 'craft_shop.dart';
import 'drill_bank.dart';
import 'financing_books.dart';
import 'trade_desk.dart';
import 'replicator_machine.dart' as rep;
import 'trade_groups.dart';
import 'cycle_outcome.dart';
import 'drill_id.dart';
import 'drill_part.dart';
import 'drill_row.dart';
import 'drill_state.dart';
import 'offline_gain.dart';
import 'strike_outcome.dart';
import 'trade_request.dart';

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
    : _random = RandomSource(seed: seed) {
    layerDensity = Computed(
      () => densityAt(layer.value),
      name: 'layer density',
    );
    power = Computed(
      () => powerWith(drills: drills.value, upgrades: drillPowerLevel.value),
      name: 'drill power',
    );
    regolithPerCycle = Computed(
      () =>
          BigDouble.fromNum(1.6) *
          BigDouble.fromNum(1.03).pow(layer.value.toDouble()) *
          BigDouble.fromNum(1.2).pow(enrichmentLevel.value.toDouble()),
      name: 'ore per cycle',
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
      if (share <= 0) {
        // No structural share yet: plain division, and the geometric
        // formula below would divide by ln(1).
        final plain = (remaining / perHit).toDouble().ceil();
        return plain < 1 ? 1 : plain;
      }
      final ratio = (remaining / perHit) * BigDouble.fromNum(share);
      final estimate = ((BigDouble.one + ratio).ln() / -math.log(1 - share))
          .ceilToDouble();
      return estimate < 1 ? 1 : estimate.toInt();
    }, name: 'hits to break');
    // The wear bar's truth, in EFFORT space. Linear hp misled the eye
    // twice over: the structural share melts a huge layer's first half in
    // a burst, then the last visible sliver hides thousands of blows.
    // Counting the journey in hits -- the same logarithm hitsToBreak
    // uses -- makes half a bar mean half the blows, both ways.
    layerEffort = Computed(() {
      final perHit = strikePower;
      if (perHit.isZero) return 0;
      final share = pierceShare;
      if (share <= 0) {
        // Linear melt, linear bar: with no structural share the hp story
        // and the effort story are the same one.
        final max = layerHpMax.value;
        if (max.isZero) return 1;
        return (1 - (layerHp.value / max).toDouble()).clamp(0.0, 1.0);
      }
      final big = BigDouble.fromNum(share);
      double journey(BigDouble hp) =>
          (BigDouble.one + (hp / perHit) * big).ln();
      final full = journey(layerHpMax.value);
      if (full <= 0) return 1;
      return (1 - journey(layerHp.value) / full).clamp(0.0, 1.0);
    }, name: 'layer effort');
    // What one manual blow ACTUALLY takes off this layer right now: the
    // bit's power plus the structural collapse of what still stands. The
    // deck quotes this, not the bare power -- the vitrine rule: against a
    // deep wall the structural term IS the blow.
    strikeBite = Computed(
      () => strikePower + layerHp.value * BigDouble.fromNum(pierceShare),
      name: 'strike bite',
    );
    // What a Restart pays: this simulation's own haul, compiled. No
    // subtraction against what past restarts banked -- the run is the unit,
    // so each one is paid in full for what it dug.
    bankableData = Computed(() => walletEarned, name: 'bankable data');

    // Everything the strike reads on its hot path is a Computed, not a
    // getter: a blow reads the band, the power and the share several
    // times, and the graph must hand back the cached value rather than
    // rebuild three powers per read.
    _strikeRegolithMean = Computed(
      () => regolithPerCycle.value * BigDouble.fromNum(strikeShareOfRig),
      name: 'strike regolith mean',
    );
    _strikeRegolithMin = Computed(
      () =>
          _strikeRegolithMean.value *
          BigDouble.fromNum(1 - regolithSpread) *
          BigDouble.fromNum(minRegolithGrowth).pow(bitLevel.value.toDouble()),
      name: 'strike regolith min',
    );
    _strikeRegolithMax = Computed(
      () =>
          _strikeRegolithMean.value *
          BigDouble.fromNum(1 + regolithSpread) *
          BigDouble.fromNum(maxRegolithGrowth).pow(driveLevel.value.toDouble()),
      name: 'strike regolith max',
    );
    // The band every vitrine quotes: already scaled by the financing
    // multiplier, so no screen assembles the product on its own.
    _strikeRegolithBand = Computed(() {
      final scale = fundScaleOf(ResourceId.regolith);
      return (
        min: _strikeRegolithMin.value * scale,
        max: _strikeRegolithMax.value * scale,
      );
    }, name: 'strike regolith band');
    _strikePower = Computed(
      () => strikePowerAt(bitLevel.value),
      name: 'strike power',
    );
    for (final id in ResourceId.values) {
      _expectedPerStrike[id] = Computed(
        () => _expectedPerStrikeOf(id),
        name: 'expected per strike ${id.name}',
      );
    }
    _expectedRegolithPerCycle = Computed(
      () =>
          _strikeRegolithMean.value *
          fundScaleOf(ResourceId.regolith) *
          (drillYieldScale(DrillId.regolith) - BigDouble.one),
      name: 'expected regolith per cycle',
    );

    _resetLayer();
  }

  /// A run with the drill already granted, for benches that study the
  /// cycle rather than the ladder. The game itself never starts this way.
  factory PrototypeSimulation.rigged({int seed = 20260825}) =>
      PrototypeSimulation(seed: seed)..drillBank.grantRig();

  /// Not final: restoring a save swaps in the streams as they stood, so the
  /// rolls carry on from where the player left them rather than replaying the
  /// same sequence from the seed every launch. The setter drops the cached
  /// stream handles, which belong to the source they were taken from.
  RandomSource get random => _random;
  set random(RandomSource value) {
    _random = value;
    _lootStreams.clear();
  }

  RandomSource _random;

  /// The loot roll's stream handles, one set per lane. Resolving six names
  /// on every blow cost six strings and six map lookups a strike; the
  /// handles are stable for the life of a source, so they are taken once.
  /// The NAMES are the parity contract and never change.
  final Map<String, _LootStreams> _lootStreams = {};

  _LootStreams _streamsFor(String prefix) => _lootStreams.putIfAbsent(
    prefix,
    () => _LootStreams(_random, prefix, oreTable),
  );

  final Signal<int> layer = Signal(0, name: 'layer');

  /// Everything the player holds. The per-resource signals below are views on
  /// it, so a readout can watch one resource without hearing about the rest.
  final Stockpile stock = Stockpile();

  /// Financing and the trade hall, each its own object with its own
  /// signals, graph and save section. The members further down that still
  /// carry the old names forward to them, so every screen and test keeps
  /// one address.
  late final FinancingBooks books = FinancingBooks(stock);
  late final TradeDesk desk = TradeDesk(
    stock,
    scaleOf: fundScaleOf,
    earn: (paid) => books.earn(paid),
    requestRoll: () => random.stream('trade.request'),
  );
  late final CraftShop shop = CraftShop(stock);

  /// What the player has automated; see [Automations]. A fresh run has
  /// nothing -- the rig is the first purchase.
  late final Automations automations = Automations(stock);

  Signal<bool> automationUnlockedOf(AutomationId id) =>
      automations.unlockedOf(id);
  bool canUnlockAutomation(AutomationId id) => automations.canUnlock(id);
  bool unlockAutomation(AutomationId id) => batch(() => automations.unlock(id));

  /// The automations themselves, each its own object with its own
  /// settings and save section. They run from [syncAutomations] once a
  /// batch, ONLINE ONLY (owner, 2026-09-02): an absence runs none and
  /// their intervals restart on return.
  late final AutoStrike autoStrike = AutoStrike();
  late final AutoSeller autoSeller = AutoSeller(stock, desk);
  late final AutoFulfil autoFulfil = AutoFulfil(stock, desk);
  late final AutoCrafter autoCrafter = AutoCrafter(stock, shop, desk);
  late final AutoBuyer autoBuyer = AutoBuyer([
    for (final part in ArmPart.values)
      AutoBuyTarget(
        key: autoBuyArmKey(part),
        canBuy: () => canUpgrade(part),
        buy: () => upgrade(part) > 0,
      ),
    for (final row in drillTable)
      for (final part in DrillPart.values)
        AutoBuyTarget(
          key: autoBuyDrillKey(row.id, part),
          canBuy: () => canUpgradeDrill(row.id, part),
          buy: () => upgradeDrill(row.id, part) > 0,
        ),
  ]);

  static String autoBuyArmKey(ArmPart part) => 'arm.${part.name}';
  static String autoBuyDrillKey(DrillId id, DrillPart part) =>
      'drill.${id.name}.${part.name}';

  /// The last acknowledged stamp the automations ran to; -1 = never.
  int automationLastSeenMs = -1;

  /// Runs every unlocked automation over the wall time since the last
  /// call. Returns how many auto-strikes fell due: the app throws them
  /// through its own strike path, so they shake and flash like a
  /// finger's.
  int syncAutomations(int nowMs) {
    observeWall(nowMs);
    final seen = wallSeenMs;
    if (automationLastSeenMs < 0) {
      automationLastSeenMs = seen;
      return 0;
    }
    final span = (seen - automationLastSeenMs) / 1000.0;
    automationLastSeenMs = seen;
    if (span <= 0) return 0;
    var strikes = 0;
    batch(() {
      if (automations.has(AutomationId.autoSell)) autoSeller.run(span);
      if (automations.has(AutomationId.autoRequests)) autoFulfil.run();
      if (automations.has(AutomationId.autoBuy)) autoBuyer.run(span);
      if (automations.has(AutomationId.autoCraft)) autoCrafter.run();
      if (automations.has(AutomationId.autoHands)) {
        strikes = autoStrike.due(span);
      }
    });
    return strikes;
  }

  Signal<BigDouble> get regolith => stock.signal(ResourceId.regolith);
  Signal<BigDouble> get crystals => stock.signal(ResourceId.crystals);
  Signal<BigDouble> get quantonium => stock.signal(ResourceId.quantonium);
  Signal<BigDouble> get credits => stock.signal(ResourceId.credits);
  Signal<BigDouble> get samples => stock.signal(ResourceId.samples);

  /// A rig always has at least one drill: total power is a product, and a
  /// count of zero would mean the game could never start.
  final Signal<int> drills = Signal(1, name: 'drills');

  /// Ore-bought upgrades to what a single drill delivers.
  final Signal<int> drillPowerLevel = Signal(0, name: 'drill power level');
  final Signal<int> modules = Signal(0, name: 'modules');
  final Signal<int> restarts = Signal(0, name: 'restarts');
  final Signal<int> energy = Signal(energyCapBase, name: 'energy');

  /// The manipulator arm's three parts, their tracks, marks and prices;
  /// see [ArmTracks]. The names below forward to it.
  late final ArmTracks arm = ArmTracks(stock);

  Signal<int> get bitLevel => arm.bitLevel;
  Signal<int> get driveLevel => arm.driveLevel;
  Signal<int> get supplyLevel => arm.supplyLevel;
  Signal<int> get bitMark => arm.bitMark;
  Signal<int> get driveMark => arm.driveMark;
  Signal<int> get supplyMark => arm.supplyMark;
  Signal<int> get bitPeak => arm.bitPeak;
  Signal<int> get drivePeak => arm.drivePeak;
  Signal<int> get supplyPeak => arm.supplyPeak;

  /// Tree levels. Purchasing is not wired up yet; they exist so the formulas
  /// read the way the prototype's do.
  final Signal<int> powerLevel = Signal(0, name: 'power level');
  final Signal<int> enrichmentLevel = Signal(0, name: 'enrichment level');
  final Signal<int> discountLevel = Signal(0, name: 'discount level');
  final Signal<int> quantoniumLevel = Signal(0, name: 'quantonium level');

  /// Data, cubes and the collapse wall; see [CollapseLedger]. The names
  /// below forward to it.
  late final CollapseLedger ledger = CollapseLedger(stock, clock);

  Signal<BigDouble> get rawData => ledger.rawData;
  Signal<BigDouble> get cycleData => ledger.cycleData;
  Signal<BigDouble> get dataWallet => ledger.dataWallet;
  Signal<int> get compilerLevel => ledger.compilerLevel;
  Signal<int> get collapses => ledger.collapses;
  Signal<int> get servers => ledger.servers;
  int get unlockedServers => ledger.unlockedServers;
  Signal<int> get cycleStartMs => ledger.cycleStartMs;

  /// The acknowledged clock every wall-time mechanic runs on; see
  /// [AcknowledgedClock]. The names below are the ones every caller and
  /// test already uses.
  final AcknowledgedClock clock = AcknowledgedClock();

  static const int absenceCapMs = AcknowledgedClock.absenceCapMs;
  int get wallSeenMs => clock.seenMs;
  set wallSeenMs(int value) => clock.seenMs = value;
  int get runStartSeenMs => clock.runStartMs;
  set runStartSeenMs(int value) => clock.runStartMs = value;
  int get lastWallMs => clock.lastWallMs;
  set lastWallMs(int value) => clock.lastWallMs = value;
  double simSeconds(int nowMs) => clock.simSeconds(nowMs);
  int seenNow(int nowMs) => clock.seenNow(nowMs);
  void observeWall(int nowMs) => clock.observe(nowMs);

  /// Damage already taken by the current layer, kept between cycles.
  final Signal<BigDouble> layerHp = Signal(BigDouble.zero, name: 'layer hp');
  final Signal<BigDouble> layerHpMax = Signal(
    BigDouble.one,
    name: 'layer hp max',
  );

  late final Computed<BigDouble> layerDensity;
  late final Computed<BigDouble> power;
  late final Computed<BigDouble> regolithPerCycle;
  late final Computed<int> hitsToBreak;

  /// How far through breaking the current layer the run is, 0..1, counted
  /// in blows rather than hp -- see the constructor note.
  late final Computed<double> layerEffort;

  /// The full bite of one manual blow against the CURRENT layer: power
  /// plus the structural share of the remaining hp.
  late final Computed<BigDouble> strikeBite;
  late final Computed<BigDouble> bankableData;

  static const int energyCapBase = ArmTracks.energyCapBase;
  static const int energyPerCapLevel = ArmTracks.energyPerCapLevel;
  static const double baseEnergySeconds = ArmTracks.baseEnergySeconds;
  static const double regenSpeedPerLevel = ArmTracks.regenSpeedPerLevel;
  static const int maxPartLevel = ArmTracks.maxPartLevel;
  static const int markSpanStep = ArmTracks.markSpanStep;
  static const int markCount = ArmTracks.markCount;
  static const int lastMark = ArmTracks.lastMark;
  static int markCeiling(int mark) => ArmTracks.markCeiling(mark);
  static int markFloor(int mark) => ArmTracks.markFloor(mark);
  static int markSpan(int mark) => ArmTracks.markSpan(mark);
  static int generationOf(int level) => ArmTracks.generationOf(level);
  static const double basePowerPerLevel = ArmTracks.basePowerPerLevel;
  static const double minRegolithGrowth = ArmTracks.minRegolithGrowth;
  static const double maxRegolithGrowth = ArmTracks.maxRegolithGrowth;
  static const double piercePerLevel = ArmTracks.piercePerLevel;

  int get energyCap => arm.energyCap.value;

  /// A regen tick always pours in exactly one point. What the supply
  /// upgrade buys is a SHORTER wait, not a bigger pour: the sustained
  /// strike rate is then literally the regen rate, and the gauge's
  /// ceiling stays what it is -- the length of a burst.
  int get energyPerRegen => 1;

  /// The wait between two points of energy, stretched by the auto-hands
  /// penalty while they run.
  double get energySeconds =>
      arm.energySeconds.value *
      (automations.has(AutomationId.autoHands)
          ? autoStrike.regenSlowdown.value
          : 1.0);

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

  double get echoChance => drillEchoChance(DrillId.regolith);

  /// Rarer than quantonium up top and commoner far down, so the early game is
  /// ore-led and the mineral becomes the thing worth going deeper for.
  double get crystalChance => crystalChanceAt(layer.value);

  static double crystalChanceAt(int layer) {
    final chance = 0.08 + layer * 0.0012;
    return chance > 0.4 ? 0.4 : chance;
  }

  static const double rawPerCube = CollapseLedger.rawPerCube;
  static const double compilerStep = CollapseLedger.compilerStep;
  static final BigDouble collapseThresholdBase =
      CollapseLedger.collapseThresholdBase;
  static const int maxPendingCollapses = CollapseLedger.maxPendingCollapses;
  static const double collapseRackGrowth = CollapseLedger.collapseRackGrowth;
  static const double collapseThresholdGrowth =
      CollapseLedger.collapseThresholdGrowth;
  static const double collapseDriftPerDay = CollapseLedger.collapseDriftPerDay;
  static const double collapseDriftCapDays =
      CollapseLedger.collapseDriftCapDays;

  int get simulationNumber => restarts.value + 1;
  int get cycleNumber => ledger.cycleNumber;
  int pendingCollapses(int nowMs) => ledger.pendingCollapses(nowMs);
  BigDouble collapseCost(int rack, int nowMs) =>
      ledger.collapseCost(rack, nowMs);
  double rackFill(int rack, int nowMs) => ledger.rackFill(rack, nowMs);
  double get compileRate => ledger.compileRate;
  BigDouble get walletEarned => ledger.walletEarned.value;
  BigDouble collapseThreshold(int nowMs) => ledger.collapseThreshold(nowMs);
  double driftDays(int nowMs) => ledger.driftDays(nowMs);
  double driftProgress(int nowMs) => ledger.driftProgress(nowMs);
  double driftDiscount(int nowMs) => ledger.driftDiscount(nowMs);

  void _recordData(BigDouble gained) => ledger.record(gained);

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
  /// The width of one offline slice: income lands and every line runs
  /// minute by minute, so a line that FEEDS another does so through the
  /// absence the way it does online -- to a minute's precision instead of
  /// a second's, which no report can tell apart. PROVISIONAL.
  static const double offlineSliceSeconds = 60;

  /// Settles a whole absence: mining income and the craft lines
  /// interleave in [offlineSliceSeconds] steps over the shared stock.
  /// One call owns the acknowledged clock and the craft stamp, so the
  /// app's settlement cannot double-count either.
  OfflineGain settleAbsence({
    required int nowMs,
    required double seconds,
    required double energyPerSecond,
    required double cycleSeconds,
  }) {
    observeWall(nowMs);
    final merged = <ResourceId, BigDouble>{};
    if (seconds > 0) {
      final crafted = <ResourceId, BigDouble>{};
      batch(() {
        var left = seconds;
        while (left > 1e-9) {
          final step = left < offlineSliceSeconds ? left : offlineSliceSeconds;
          final g = claimOffline(
            seconds: step,
            energyPerSecond: energyPerSecond,
            cycleSeconds: cycleSeconds,
          );
          for (final entry in g.gained.entries) {
            merged[entry.key] =
                (merged[entry.key] ?? BigDouble.zero) + entry.value;
          }
          // The benches run at the SAME offline efficiency as the mine:
          // absence throttles everything the AI runs -- one rule, one
          // number, and the meta node that raises it will raise both.
          // Time dilation, so a unit in progress simply advances slower.
          shop.run(step * offlineEfficiency, crafted, offline: true);
          // The replicators obey the same throttle, and running inside
          // the slices lets them compound what the mine and the benches
          // deliver as it arrives.
          for (final entry in _runReplicator(
            step * offlineEfficiency,
          ).entries) {
            crafted[entry.key] =
                (crafted[entry.key] ?? BigDouble.zero) + entry.value;
          }
          left -= step;
        }
      });
      for (final entry in crafted.entries) {
        merged[entry.key] = (merged[entry.key] ?? BigDouble.zero) + entry.value;
      }
    }
    craftLastSeenMs = wallSeenMs;
    replicatorLastSeenMs = wallSeenMs;
    automationLastSeenMs = wallSeenMs;
    autoStrike.restamp();
    autoSeller.restamp();
    autoBuyer.restamp();
    if (merged.isEmpty) return OfflineGain.none;
    return OfflineGain(
      seconds: seconds,
      cycles: cycleSeconds > 0 ? (seconds / cycleSeconds).floor() : 0,
      efficiency: offlineEfficiency,
      gained: merged,
    );
  }

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

  /// The drills, their tracks and prices; see [DrillBank]. The names below
  /// forward to it so every screen and test keeps one address.
  late final DrillBank drillBank = DrillBank(stock);

  BigDouble get rigCost => DrillBank.rigCost;
  bool get canBuyRig => drillBank.canBuyRig;
  bool buyRig() => batch(() => drillBank.buyRig());

  static const double drillRadiusBase = DrillBank.drillRadiusBase;
  static const double drillRadiusPerLevel = DrillBank.drillRadiusPerLevel;
  static const double drillSpeedStep = DrillBank.drillSpeedStep;
  static const double drillIntervalFloor = DrillBank.drillIntervalFloor;
  static const double drillCritBase = DrillBank.drillCritBase;
  static const double drillCritPerLevel = DrillBank.drillCritPerLevel;
  static const double drillCritPower = DrillBank.drillCritPower;
  static const double drillEchoBase = DrillBank.drillEchoBase;
  static const double drillEchoPerLevel = DrillBank.drillEchoPerLevel;
  static const List<DrillRow> drillTable = DrillBank.drillTable;
  static DrillRow rowFor(DrillId id) => DrillBank.rowFor(id);
  static int drillDriveCap(DrillId id) => DrillBank.driveCap(id);
  static BigDouble drillCostOf(DrillPart part, int level) =>
      DrillBank.costOf(part, level);

  Map<DrillId, DrillState> get drillState => drillBank.states;
  DrillState drill(DrillId id) => drillBank.drill(id);
  bool drillOwned(DrillId id) => drillBank.owned(id);
  double drillRadius(DrillId id) => drillBank.radius(id);
  double drillArea(DrillId id) => drillBank.area(id);
  BigDouble drillYieldScale(DrillId id) => drillBank.yieldScale(id);
  double drillInterval(DrillId id) => drillBank.interval(id);
  double drillCritChance(DrillId id) => drillBank.critChance(id);
  double drillEchoChance(DrillId id) => drillBank.echoChance(id);
  BigDouble drillUpgradeCost(DrillId id, DrillPart part) =>
      drillBank.upgradeCost(id, part);
  int drillCap(DrillId id, DrillPart part) => drillBank.cap(id, part);
  bool drillAtCap(DrillId id, DrillPart part) => drillBank.atCap(id, part);
  bool canUpgradeDrill(DrillId id, DrillPart part) =>
      drillBank.canUpgrade(id, part);
  int upgradeDrill(DrillId id, DrillPart part, {int levels = 1}) =>
      batch(() => drillBank.upgrade(id, part, levels: levels));
  int affordableDrillLevels(DrillId id, DrillPart part) =>
      drillBank.affordableLevels(id, part);

  /// The band a strike's regolith lands in.
  ///
  /// The two ends move on different parts: the bit raises the FLOOR (a
  /// heavier head never comes back empty) and the drive raises the CEILING
  /// (a harder blow is what shakes a jackpot loose). PROVISIONAL rates.
  late final Computed<BigDouble> _strikeRegolithMin;
  late final Computed<BigDouble> _strikeRegolithMax;
  late final Computed<BigDouble> _strikeRegolithMean;
  late final Computed<({BigDouble min, BigDouble max})> _strikeRegolithBand;

  BigDouble get strikeRegolithMin => _strikeRegolithMin.value;
  BigDouble get strikeRegolithMax => _strikeRegolithMax.value;

  /// The band as every vitrine must quote it -- financing already applied.
  ({BigDouble min, BigDouble max}) get strikeRegolithBand =>
      _strikeRegolithBand.value;

  BigDouble armPowerAt(int level) => arm.powerAt(level, baseStrikePower);

  double get pierceShare => arm.pierceShare.value;

  late final Computed<BigDouble> _strikePower;

  BigDouble get strikePower => _strikePower.value;

  /// The blow, never weaker than a share of the rig: an arm that could not
  /// keep up with its own drills would make the manual lane noise by the
  /// second stratum.
  BigDouble strikePowerAt(int level) {
    final own = armPowerAt(level);
    // No rig to lean on before the drill is bought: the arm swings alone.
    if (!drillOwned(DrillId.regolith)) return own;
    final scaled = power.value * BigDouble.fromNum(strikeShareOfRig);
    return scaled > own ? scaled : own;
  }

  static BigDouble costOf(ArmPart part, int level) =>
      ArmTracks.costOf(part, level);

  Signal<int> levelOf(ArmPart part) => arm.levelOf(part);
  Signal<int> markOf(ArmPart part) => arm.markOf(part);
  Signal<int> peakOf(ArmPart part) => arm.peakOf(part);
  int knownGeneration(ArmPart part) => arm.knownGeneration(part);
  int ceilingOf(ArmPart part) => arm.ceilingOf(part);
  bool atMarkCeiling(ArmPart part) => arm.atMarkCeiling(part);
  bool canEvolve(ArmPart part) => arm.canEvolve(part);
  int? evolve(ArmPart part) => batch(() => arm.evolve(part));
  bool atMaxLevel(ArmPart part) => arm.atMaxLevel(part);
  BigDouble upgradeCost(ArmPart part) => arm.upgradeCost(part);
  bool canUpgrade(ArmPart part) => arm.canUpgrade(part);
  int upgrade(ArmPart part, {int levels = 1}) =>
      batch(() => arm.upgrade(part, levels: levels));
  int affordableLevels(ArmPart part) => arm.affordableLevels(part);

  /// What one strike is expected to bring out of the face: the drop at this
  /// depth times how often the lane pays. A locked ore is worth nothing.
  final Map<ResourceId, Computed<BigDouble>> _expectedPerStrike = {};

  BigDouble expectedPerStrike(ResourceId id) => _expectedPerStrike[id]!.value;

  BigDouble _expectedPerStrikeOf(ResourceId id) {
    switch (id) {
      case ResourceId.regolith:
        return _strikeRegolithMean.value * fundScaleOf(ResourceId.regolith);
      case ResourceId.crystals:
        return crystalDropAt(layer.value) *
            BigDouble.fromNum(crystalChance) *
            fundScaleOf(ResourceId.crystals);
      case ResourceId.quantonium:
        return quantoniumDropAt(layer.value).big *
            BigDouble.fromNum(strikeQuantoniumChance);
      case ResourceId.rawData:
        return rawDataDropAt(layer.value) *
            BigDouble.fromNum(rawDataChance) *
            fundScaleOf(ResourceId.rawData);
      default:
        for (final row in oreTable) {
          if (row.id != id) continue;
          if (layer.value < row.unlockAt) return BigDouble.zero;
          return oreDropAt(layer.value) *
              BigDouble.fromNum(row.chance) *
              fundScaleOf(row.id);
        }
        return BigDouble.zero;
    }
  }

  /// What one drill cycle extracts on its OWN, beyond the strike it throws.
  ///
  /// The regolith drill is the first to fill the slot the typed drills
  /// were promised: it mines ITS resource wider by the face it covers,
  /// (area - 1) of the strike's own cut, so the cycle's total regolith
  /// is the roll times the area. Everything else still belongs to
  /// strikes alone -- the drill's multiplier never touches the rest of
  /// the table (owner, 2026-09-01).
  late final Computed<BigDouble> _expectedRegolithPerCycle;

  BigDouble expectedPerCycle(ResourceId id) => id == ResourceId.regolith
      ? _expectedRegolithPerCycle.value
      : BigDouble.zero;

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
    if (cycleSeconds <= 0 || !drillOwned(DrillId.regolith)) return byHand;
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
  /// the blow. The crit is rolled inside the loot roll (on this lane's own
  /// stream) and multiplies the BLOW only -- never the haul.
  StrikeOutcome strike() => batch(() {
    if (energy.value < strikeCost) return StrikeOutcome.none;
    energy.value = energy.value - strikeCost;

    final rolled = _rollLoot(prefix: 'strike.');
    final damage = rolled.critical
        ? strikePower * BigDouble.fromNum(strikeCritPower)
        : strikePower;
    final result = _applyDamage(damage);
    final ores = Map<ResourceId, BigDouble>.of(rolled.loot)
      ..remove(ResourceId.regolith);
    return StrikeOutcome(
      spent: strikeCost,
      layersBroken: result.broken,
      thickLayersBroken: result.thickBroken,
      regolithGained: rolled.loot[ResourceId.regolith] ?? BigDouble.zero,
      oresGained: ores,
      critical: rolled.critical,
    );
  });

  /// What every strike carries out of the face, whoever struck.
  ///
  /// Regolith always, inside the promised band; ores, crystals, the
  /// quantonium glint and the substrate by chance at the table's own odds.
  /// Each lane rolls on its own streams ([prefix]), so manual digging can
  /// never shift the drill's sequence. Every lane pays its financing
  /// multiplier here and nowhere else.
  ({bool critical, Map<ResourceId, BigDouble> loot}) _rollLoot({
    required String prefix,
    double? critChance,
  }) {
    final loot = <ResourceId, BigDouble>{};
    final streams = _streamsFor(prefix);

    // The one crit in the game. Rolled here, on this lane's stream, so the
    // sequence stays where it always was; it scales the BLOW the caller
    // throws, never the haul (owner, 2026-08-27) -- what the loot table
    // promises is exactly what any strike pays.
    final critical = streams.crit.chance(critChance ?? strikeCritChance);

    // A roll inside the band the loot table promises. The band's ends are
    // upgraded separately, so the roll walks between them rather than around
    // a mean -- one draw either way, so adding the parts shifted no stream.
    final low = strikeRegolithMin;
    final span = strikeRegolithMax - low;
    final spread = streams.regolith.nextDouble();
    loot[ResourceId.regolith] = _payRegolith(
      low + span * BigDouble.fromNum(spread),
    );

    for (final row in oreTable) {
      if (layer.value < row.unlockAt) continue;
      if (streams.ores[row.id]!.chance(row.chance)) {
        final drop = oreDropAt(layer.value) * fundScaleOf(row.id);
        stock.add(row.id, drop);
        loot[row.id] = drop;
      }
    }

    if (streams.crystal.chance(crystalChance)) {
      final drop =
          crystalDropAt(layer.value) * fundScaleOf(ResourceId.crystals);
      stock.add(ResourceId.crystals, drop);
      loot[ResourceId.crystals] = drop;
    }

    // Named apart from the cycle's own anti-brick stream: the loot glint and
    // the heartbeat drip must never share a sequence.
    if (streams.quantonium.chance(strikeQuantoniumChance)) {
      final drop = quantoniumDropAt(layer.value).big;
      stock.add(ResourceId.quantonium, drop);
      loot[ResourceId.quantonium] = drop;
    }

    // The substrate lane. Its own stream, named apart from everything else,
    // so adding it shifted no roll that came before it.
    if (streams.rawData.chance(rawDataChance)) {
      final drop = rawDataDropAt(layer.value) * fundScaleOf(ResourceId.rawData);
      _recordData(drop);
      loot[ResourceId.rawData] = drop;
    }

    return (critical: critical, loot: loot);
  }

  CycleOutcome _cycle(int chain) {
    // No rig, no cycle: until the drill is bought the face is dug by
    // hand alone, and the engine's ticks pass through empty.
    if (!drillOwned(DrillId.regolith)) return CycleOutcome.none;
    // The cycle is damage plus THE SAME strike a click throws -- same
    // table, same odds, same amounts, and by the REAL strike's rules:
    // the drill's multiplier never touches strike loot (owner,
    // 2026-09-01). The only crit in the game is the strike's, and it
    // lives inside the loot roll.
    final rolled = _rollLoot(
      prefix: '',
      critChance: drillCritChance(DrillId.regolith),
    );
    final loot = rolled.loot;

    // What the drill MINES on its own: only its specified resource,
    // widened by the face it covers. The strike already paid one cut,
    // so the drill adds the remaining (area - 1) of the same roll --
    // at radius level zero this is exactly nothing, and the cycle is a
    // bare real strike.
    final struckRegolith = loot[ResourceId.regolith] ?? BigDouble.zero;
    final widened =
        struckRegolith * (drillYieldScale(DrillId.regolith) - BigDouble.one);
    if (!widened.isZero) {
      // The strike's cut already carries the financing multiplier, so the
      // widening adds bare on top of it.
      stock.add(ResourceId.regolith, widened);
      loot[ResourceId.regolith] = struckRegolith + widened;
    }
    final gained = loot[ResourceId.regolith] ?? BigDouble.zero;
    final crystalsGained = loot[ResourceId.crystals] ?? BigDouble.zero;

    // The anti-brick drip lives in the loot table now: every strike can
    // shake quantonium loose, and the cycle rolls it through its own strike.
    final quantoniumGained =
        loot[ResourceId.quantonium]?.toDouble().round() ?? 0;

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

  /// The ONE door regolith enters the store through: every lane -- the
  /// strike's roll, the drill's widening, the break payouts -- pays the
  /// financing multiplier here, so no payout can ever forget it again.
  BigDouble _payRegolith(BigDouble base) {
    final paid = base * fundScaleOf(ResourceId.regolith);
    stock.add(ResourceId.regolith, paid);
    return paid;
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
      payout =
          rawDataDropAt(layer.value) *
          BigDouble.fromNum(thickSpan) *
          fundScaleOf(ResourceId.rawData);
      final bonus = BigDouble.fromNum(thickSpan);
      final crystals =
          crystalDropAt(layer.value) * bonus * fundScaleOf(ResourceId.crystals);
      final quantonium = (quantoniumDropAt(layer.value) * thickSpan).big;
      _payRegolith(regolithPerCycle.value * bonus);
      stock.add(ResourceId.crystals, crystals);
      for (final row in oreTable) {
        if (layer.value < row.unlockAt) continue;
        stock.add(row.id, oreDropAt(layer.value) * bonus * fundScaleOf(row.id));
      }
      stock.add(ResourceId.quantonium, quantonium);
      stock.add(ResourceId.samples, BigDouble.one);
    } else {
      _payRegolith(regolithPerCycle.value * BigDouble.fromNum(1.5));
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

  // ---------------------------------------------------------- financing

  static final BigDouble roundCostBase = FinancingBooks.roundCostBase;
  static const double roundCostGrowth = FinancingBooks.roundCostGrowth;
  static const List<({ResourceId id, double step})> fundTable =
      FinancingBooks.fundTable;
  static const double fundSpentStep = FinancingBooks.fundSpentStep;
  static const double fundRankStep = FinancingBooks.fundRankStep;
  static const int fundCapBase = FinancingBooks.fundCapBase;
  static const int fundCapPerRank = FinancingBooks.fundCapPerRank;
  static double fundStep(ResourceId id) => FinancingBooks.fundStep(id);
  static int investCostAt(int level) => FinancingBooks.investCostAt(level);
  static int tranchesInto(int levels) => FinancingBooks.tranchesInto(levels);
  static int rankThreshold(int rank) => FinancingBooks.rankThreshold(rank);

  int get tranchesPerRound => books.tranchesPerRound;
  Signal<BigDouble> get creditsEarned => books.creditsEarned;
  Signal<int> fundingOf(ResourceId id) => books.fundingOf(id);
  int get financeRound => books.round;
  BigDouble roundFloor(int round) => books.roundFloor(round);
  BigDouble get nextRoundCost => books.nextRoundCost;
  double get roundProgress => books.roundProgress;
  int investCost(ResourceId id) => books.investCost(id);
  int get tranchesSpent => books.tranchesSpent;
  Signal<int> get tranchesGranted => books.tranchesGranted;
  int grantedLevelsOf(ResourceId id) => books.grantedLevelsOf(id);
  bool get fundingWasReset => books.wasReset;
  set fundingWasReset(bool value) => books.wasReset = value;
  int get tranchesFree => books.tranchesFree;
  int grantFundLevels(ResourceId id, int levels) =>
      books.grantLevels(id, levels);
  int get financeRank => books.rank;
  double get rankProgress => books.rankProgress;
  int get fundCap => books.cap;
  bool canInvest(ResourceId id) => books.canInvest(id);
  bool investTranche(ResourceId id) => books.invest(id);
  BigDouble get fundGlobalScale => books.globalScale;

  /// The effective multiplier a resource's income wears; see
  /// [FinancingBooks.scaleOf].
  BigDouble fundScaleOf(ResourceId id) => books.scaleOf(id);

  // --------------------------------------------------------- replicator

  /// The machines, one per craftable resource, each its own object with
  /// its own signals and graph -- see [ReplicatorMachine]. The tier
  /// tables live beside it; the statics below forward to them so every
  /// caller keeps one address.
  late final Map<ResourceId, rep.ReplicatorMachine> _replicators = {
    for (final id in rep.replicableIds) id: rep.ReplicatorMachine(stock, id),
  };

  rep.ReplicatorMachine replicator(ResourceId id) => _replicators[id]!;

  static const double replicatorMinSeconds = rep.replicatorMinSeconds;
  static const double replicatorSpeedDecay = rep.replicatorSpeedDecay;
  static List<ResourceId> get replicableIds => rep.replicableIds;
  static int replicatorBaseYield(ResourceId id) => rep.replicatorBaseYield(id);
  static double replicatorDurationFactor(ResourceId id) =>
      rep.replicatorDurationFactor(id);
  static int replicatorAmountStep(ResourceId id) =>
      rep.replicatorAmountStep(id);
  static double replicatorUnlockCost(ResourceId id) =>
      rep.replicatorUnlockCost(id);
  static double replicatorUnlockQuant(ResourceId id) =>
      rep.replicatorUnlockQuant(id);
  static double replicatorSecondsAt(ResourceId id, int speedLevel) =>
      rep.replicatorSecondsAt(id, speedLevel);

  Signal<bool> replicatorUnlockedOf(ResourceId id) => replicator(id).unlocked;
  Signal<int> replicatorSpeedOf(ResourceId id) => replicator(id).speed;
  Signal<int> replicatorAmountOf(ResourceId id) => replicator(id).amount;
  Signal<double> replicatorFractionOf(ResourceId id) => replicator(id).fraction;
  double replicatorSeconds(ResourceId id) => replicator(id).seconds.value;
  int replicatorYieldOf(ResourceId id) => replicator(id).yieldPerCycle.value;
  BigDouble replicatorSpeedCost(ResourceId id) =>
      replicator(id).speedCost.value;
  BigDouble replicatorAmountCost(ResourceId id) =>
      replicator(id).amountCost.value;
  BigDouble replicatorSpeedQuant(ResourceId id) =>
      replicator(id).speedQuant.value;
  BigDouble replicatorAmountQuant(ResourceId id) =>
      replicator(id).amountQuant.value;
  BigDouble replicatorPerSecondOf(ResourceId id) =>
      replicator(id).perSecond.value;

  bool canUnlockReplicator(ResourceId id) => replicator(id).canUnlock;
  bool unlockReplicator(ResourceId id) => batch(() => replicator(id).unlock());
  bool canUpgradeReplicatorSpeed(ResourceId id) => replicator(id).canSpeedUp;
  bool canUpgradeReplicatorAmount(ResourceId id) => replicator(id).canWiden;
  bool upgradeReplicatorSpeed(ResourceId id) =>
      batch(() => replicator(id).speedUp());
  bool upgradeReplicatorAmount(ResourceId id) =>
      batch(() => replicator(id).widen());

  /// The last [seenNow] stamp the replicators settled to; -1 = never.
  int replicatorLastSeenMs = -1;

  /// Advances every unlocked replicator by the wall time since the last
  /// call -- they all run at once, each on its own pile. Returns what the
  /// span produced, for the offline window.
  Map<ResourceId, BigDouble> syncReplicator(int nowMs) {
    observeWall(nowMs);
    final seen = wallSeenMs;
    if (replicatorLastSeenMs < 0) {
      replicatorLastSeenMs = seen;
      return const {};
    }
    final span = (seen - replicatorLastSeenMs) / 1000.0;
    replicatorLastSeenMs = seen;
    if (span <= 0) return const {};
    return _runReplicator(span);
  }

  /// The conversion itself, span in seconds: every machine walks its
  /// cycles, banking the unfinished fraction -- so one long span equals
  /// the same span in pieces. Payouts land in whole cycles only, like
  /// the bench's prepaid units. Shared by the online sync and the
  /// sliced absence settlement.
  Map<ResourceId, BigDouble> _runReplicator(double span) {
    final gains = <ResourceId, BigDouble>{};
    batch(() {
      for (final machine in _replicators.values) {
        final gained = machine.run(span);
        if (!gained.isZero) gains[machine.id] = gained;
      }
    });
    return gains;
  }

  // -------------------------------------------------------------- craft

  List<CraftLine> get craftLines => shop.lines;
  int get craftLastSeenMs => shop.lastSeenMs;
  set craftLastSeenMs(int value) => shop.lastSeenMs = value;

  /// Advances every line by the wall time since the last call and returns
  /// what the span produced, for the offline window. Banks the wall span
  /// first: the acknowledged clock only advances when observed, and craft
  /// must not depend on someone else having looked.
  Map<ResourceId, BigDouble> syncCraft(int nowMs) {
    observeWall(nowMs);
    return shop.sync(wallSeenMs);
  }

  void assignCraftRecipe(
    int index,
    ResourceId? output, {
    int limit = -1,
    int? tier,
  }) => shop.assign(index, output, limit: limit, tier: tier);

  void setCraftHalted(int index, bool value) => shop.setHalted(index, value);
  bool setCraftTier(int index, int value) => shop.setTier(index, value);
  BigDouble get craftLineCost => shop.lineCost;
  bool get canBuyCraftLine => shop.canBuyLine;
  bool buyCraftLine() => shop.buyLine();
  BigDouble craftCapCost(int index) => shop.capCost(index);
  bool canBuyCraftCap(int index) => shop.canBuyCap(index);
  bool buyCraftCap(int index) => shop.buyCap(index);
  BigDouble craftSpeedCost(int index) => shop.speedCost(index);
  bool canBuyCraftSpeed(int index) => shop.canBuySpeed(index);
  bool buyCraftSpeed(int index) => shop.buySpeed(index);

  // -------------------------------------------------------------- trade

  static const List<({ResourceId id, double price})> priceTable =
      TradeDesk.priceTable;
  static const List<int> sellShares = TradeDesk.sellShares;
  static const List<({String key, List<ResourceId> ids})> tradeGroups =
      tradeGroupTable;
  static const int requestIntervalMs = TradeDesk.requestIntervalMs;
  static const int requestLifetimeMs = TradeDesk.requestLifetimeMs;
  static const double requestShareFloor = TradeDesk.requestShareFloor;
  static const double requestShareCeil = TradeDesk.requestShareCeil;
  static const double requestPremiumFloor = TradeDesk.requestPremiumFloor;
  static const double requestPremiumCeil = TradeDesk.requestPremiumCeil;
  static const double requestSecondLineChance =
      TradeDesk.requestSecondLineChance;

  Signal<bool> sellingOf(ResourceId id) => desk.sellingOf(id);
  Signal<bool> sellingGroupOf(String key) => desk.sellingGroupOf(key);
  bool sellsInSweep(ResourceId id) => desk.sellsInSweep(id);
  Signal<int> sellShareOf(ResourceId id) => desk.sellShareOf(id);
  BigDouble sellPrice(ResourceId id) => desk.sellPrice(id);
  BigDouble sellLot(ResourceId id) => desk.sellLot(id);
  BigDouble sellYield(ResourceId id) => desk.sellYield(id);
  BigDouble sellAllYield() => desk.sellAllYield;
  BigDouble sellPosition(ResourceId id) => desk.sellPosition(id);
  BigDouble sellAll() => desk.sellAll();

  int get requestSlots => desk.requestSlots;
  List<TradeRequest> get requests => desk.requests;
  int get nextRequestAtMs => desk.nextRequestAtMs;
  set nextRequestAtMs(int value) => desk.nextRequestAtMs = value;
  void syncRequests(int nowMs) => desk.syncRequests(nowMs);
  BigDouble requestPayout(TradeRequest request) => desk.requestPayout(request);
  bool canFulfil(TradeRequest request) => desk.canFulfil(request);
  bool fulfilRequest(TradeRequest request) => desk.fulfilRequest(request);

  /// The run, as a plain map.
  ///
  /// Derived values are left out and recomputed on the way back in: writing
  /// `layerHpMax` would let a save disagree with the density formula, and the
  /// formula has to win.
  Map<String, Object?> toJson() => {
    'layer': layer.value,
    if (runStartSeenMs != 0) 'simStart': runStartSeenMs,
    'layerHp': layerHp.value.toJson(),
    'drills': drills.value,
    'drillPower': drillPowerLevel.value,
    'modules': modules.value,
    'restarts': restarts.value,
    'collapses': collapses.value,
    'servers': servers.value,
    // Only departures from a fresh run are written, section by section:
    // a missing key reads back as its default, so nothing below can be
    // misread by an older build, and a new section follows the same rule
    // instead of copying "write everything".
    'data': ledger.toJson(),
    'energy': energy.value,
    'bores': drillBank.toJson(),
    'automation': {
      ...automations.toJson(),
      if (autoStrike.toJson().isNotEmpty) 'strike': autoStrike.toJson(),
      if (autoSeller.toJson().isNotEmpty) 'sell': autoSeller.toJson(),
      if (autoFulfil.toJson().isNotEmpty) 'req': autoFulfil.toJson(),
      if (autoBuyer.toJson().isNotEmpty) 'buy': autoBuyer.toJson(),
      if (autoCrafter.toJson().isNotEmpty) 'craft': autoCrafter.toJson(),
    },
    'arm': arm.toJson(),
    'tree': {
      if (powerLevel.value != 0) 'power': powerLevel.value,
      if (enrichmentLevel.value != 0) 'enrichment': enrichmentLevel.value,
      if (discountLevel.value != 0) 'discount': discountLevel.value,
      if (quantoniumLevel.value != 0) 'quantonium': quantoniumLevel.value,
    },
    'stock': stock.toJson(),
    'clock': clock.toJson(),
    'finance': books.toJson(),
    if (replicatorLastSeenMs >= 0 ||
        _replicators.values.any((machine) => machine.unlocked.value))
      'replicator': {
        if (replicatorLastSeenMs >= 0) 'last': replicatorLastSeenMs,
        if (_replicators.values.any((machine) => machine.unlocked.value))
          'u': [
            for (final machine in _replicators.values)
              if (machine.unlocked.value) machine.id.name,
          ],
        for (final machine in _replicators.values) ...machine.toJson(),
      },
    'craft': shop.toJson(),
    'trade': desk.toJson(),
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
    ledger.readJson(json['data']);
    final automation = json['automation'];
    automations.readJson(automation);
    autoStrike.readJson(automation is Map ? automation['strike'] : null);
    autoSeller.readJson(automation is Map ? automation['sell'] : null);
    autoFulfil.readJson(automation is Map ? automation['req'] : null);
    autoBuyer.readJson(automation is Map ? automation['buy'] : null);
    autoCrafter.readJson(automation is Map ? automation['craft'] : null);
    automationLastSeenMs = -1;
    drillBank.readJson(json['bores']);
    arm.readJson(json['arm']);
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

    clock.readJson(json['clock']);

    books.readJson(json['finance']);

    desk.readJson(json['trade']);

    final replicator = json['replicator'];
    replicatorLastSeenMs = -1;
    for (final machine in _replicators.values) {
      machine.reset();
    }
    if (replicator is Map) {
      final opened = replicator['u'];
      for (final machine in _replicators.values) {
        machine.readJson(
          replicator,
          unlocked: opened is List && opened.contains(machine.id.name),
        );
      }
      replicatorLastSeenMs = _readInt(replicator['last'], -1);
    }
    shop.readJson(json['craft']);

    final rolls = json['random'];
    if (rolls is Map) {
      // A save whose values are corrupt (right shape, wrong contents)
      // must still load: the streams fall back to fresh ones rather than
      // throwing past the backup-and-quarantine path.
      try {
        random = RandomSource.fromJson(Map<String, dynamic>.from(rolls));
      } on Object {
        random = RandomSource(seed: random.seed);
      }
    }

    runStartSeenMs = _readInt(json['simStart'], 0);
    _resetLayer();
    final remaining = _readBig(json['layerHp']);
    if (remaining > BigDouble.zero && remaining < layerHpMax.value) {
      layerHp.value = remaining;
    }
  });

  /// The three readers every section goes through. Each is lenient by
  /// design: a save with the right shape and a wrong value falls back to
  /// the default rather than throwing -- the player never loses a run to
  /// one bad figure.
  static int _readInt(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static BigDouble _readBig(Object? value) => value is String
      ? (BigDouble.tryParse(value) ?? BigDouble.zero)
      : BigDouble.zero;

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

/// One lane's loot-roll stream handles, resolved once. The names ARE the
/// parity contract: a rename shifts every roll that follows.
class _LootStreams {
  _LootStreams(RandomSource source, String prefix, Iterable<dynamic> ores)
    : crit = source.stream('${prefix}loot.crit'),
      regolith = source.stream('${prefix}regolith'),
      crystal = source.stream('${prefix}crystal'),
      quantonium = source.stream('${prefix}quantonium.loot'),
      rawData = source.stream('${prefix}rawdata'),
      ores = {
        for (final row in ores)
          row.id as ResourceId: source.stream('$prefix${row.stream}'),
      };

  final RandomStream crit;
  final RandomStream regolith;
  final RandomStream crystal;
  final RandomStream quantonium;
  final RandomStream rawData;
  final Map<ResourceId, RandomStream> ores;
}
