import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'affordable_walk.dart';
import 'arm_part.dart';

/// The manipulator arm: three PARTS, each its own upgrade track and its
/// own mark ladder. One track per part rather than one per stat -- a part
/// carries several buffs at once, and later generations of it add more;
/// the player upgrades a piece of hardware, not a number.
///
/// What the arm swings on its own lives here; how that blow meets the rig
/// and the rock is the simulation's.
class ArmTracks {
  ArmTracks(this._stock) {
    energyCap = Computed(
      () => energyCapBase + energyPerCapLevel * supplyLevel.value,
      name: 'energy cap',
    );
    energySeconds = Computed(
      () => baseEnergySeconds / (1 + regenSpeedPerLevel * supplyLevel.value),
      name: 'energy seconds',
    );
    pierceShare = Computed(
      () => piercePerLevel * driveLevel.value,
      name: 'pierce share',
    );
  }

  final Stockpile _stock;

  final Signal<int> bitLevel = Signal(0, name: 'bit level');
  final Signal<int> driveLevel = Signal(0, name: 'drive level');
  final Signal<int> supplyLevel = Signal(0, name: 'supply level');

  /// The generation each part is BUILT to, 0 (Mk I) through 4 (Mk V).
  ///
  /// Deliberately its own number rather than something read off the
  /// level: a part does not grow into the next mark by being levelled, it
  /// is rebuilt into it, and until the player does that the next mark's
  /// buffs are not running and the level cannot pass this mark's ceiling.
  final Signal<int> bitMark = Signal(0, name: 'bit mark');
  final Signal<int> driveMark = Signal(0, name: 'drive mark');
  final Signal<int> supplyMark = Signal(0, name: 'supply mark');

  /// The highest mark each part has EVER been built to, which is a
  /// different thing from where it stands: a restart takes the hardware
  /// back, and what the player learned about it while owning it does not
  /// go with it. The part sheet reads these, so a mark once built stays
  /// readable forever.
  final Signal<int> bitPeak = Signal(0, name: 'bit peak');
  final Signal<int> drivePeak = Signal(0, name: 'drive peak');
  final Signal<int> supplyPeak = Signal(0, name: 'supply peak');

  // --------------------------------------------------------------- energy

  static const int energyCapBase = 250;

  /// Each supply level adds this many points to the gauge.
  static const int energyPerCapLevel = 10;

  late final Computed<int> energyCap;

  /// The wait between two points at rest.
  static const double baseEnergySeconds = 2.0;

  /// Each supply level adds this share to the regen RATE, additively:
  /// five hundred levels come out at +50%, so the wait bottoms out at
  /// 1.333 s. Speeding the rate rather than shortening the wait is what
  /// keeps the formula from crossing zero at the top of the track.
  static const double regenSpeedPerLevel = 0.001;

  late final Computed<double> energySeconds;

  // ---------------------------------------------------------------- marks

  /// Five generations on a growing ladder (owner, 2026-09-01): the
  /// listed level is where each mark is OBTAINED -- Mk I at 0, Mk II at
  /// 100, Mk III at 300, Mk IV at 600, Mk V at 1000. So Mk I plays the
  /// first hundred, and every next span is a hundred longer.
  static const int maxPartLevel = 1000;
  static const int markSpanStep = 100;
  static const int markCount = 5;
  static const int lastMark = markCount - 1;

  /// The total level at which [mark] becomes available to build.
  static int markCeiling(int mark) => markSpanStep * mark * (mark + 1) ~/ 2;

  /// Where the span PLAYED while carrying [mark] begins.
  static int markFloor(int mark) => markCeiling(mark);

  /// Levels played while carrying [mark]: 100, 200, 300, 400, and none
  /// on the summit -- Mk V is obtained at the track's very top.
  static int markSpan(int mark) =>
      mark >= markCount - 1 ? 0 : markCeiling(mark + 1) - markCeiling(mark);

  /// The mark a level has EARNED the threshold of, 0 (Mk I) to 4.
  static int generationOf(int level) {
    var generation = 0;
    while (generation < markCount - 1 && level >= markCeiling(generation + 1)) {
      generation++;
    }
    return generation;
  }

  // ---------------------------------------------------------------- buffs

  /// PROVISIONAL buff rates. Balance comes later; what is meant to last is
  /// that each part carries several of these at once.
  static const double basePowerPerLevel = 10;
  static const double minRegolithGrowth = 1.03;
  static const double maxRegolithGrowth = 1.05;
  static const double piercePerLevel = 0.00001;

  /// The share of a layer's REMAINING hp every blow collapses on top of
  /// its own power. EARNED, never born (owner, 2026-09-01): only the
  /// drive's levels count, so a fresh arm digs on muscle alone and the
  /// log-of-overmatch melt is something the player builds.
  late final Computed<double> pierceShare;

  /// What the arm swings on its own at [level], before the rig is
  /// consulted, from [baseStrikePower].
  BigDouble powerAt(int level, double baseStrikePower) =>
      BigDouble.fromNum(baseStrikePower + basePowerPerLevel * level);

  // --------------------------------------------------------------- prices

  /// PROVISIONAL price curves. Owner's multipliers (2026-09-01),
  /// reverse-engineered from the reference ladders: supply is the steep
  /// track.
  static BigDouble costOf(ArmPart part, int level) {
    final base = switch (part) {
      ArmPart.bit => 120.0,
      ArmPart.drive => 200.0,
      ArmPart.supply => 150.0,
    };
    final growth = switch (part) {
      ArmPart.bit => 1.353,
      ArmPart.drive => 1.365,
      ArmPart.supply => 3.04,
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

  /// As far as [part] can be levelled before it has to be rebuilt: the
  /// level at which the NEXT mark is obtained. The summit levels to the
  /// track's top and rebuilds into nothing.
  int ceilingOf(ArmPart part) {
    final mark = markOf(part).value;
    return mark >= lastMark ? maxPartLevel : markCeiling(mark + 1);
  }

  bool atMarkCeiling(ArmPart part) => levelOf(part).value >= ceilingOf(part);

  /// A part at its ceiling with a mark left to build is ready to evolve.
  bool canEvolve(ArmPart part) =>
      atMarkCeiling(part) && markOf(part).value < lastMark;

  /// Rebuilds [part] into its next mark. Returns the mark it now carries,
  /// or null when it was not ready -- the caller has nothing to celebrate
  /// then.
  int? evolve(ArmPart part) {
    if (!canEvolve(part)) return null;
    final mark = markOf(part);
    mark.value = mark.value + 1;
    final peak = peakOf(part);
    if (mark.value > peak.value) peak.value = mark.value;
    return mark.value;
  }

  bool atMaxLevel(ArmPart part) =>
      levelOf(part).value >= maxPartLevel && markOf(part).value >= lastMark;

  BigDouble upgradeCost(ArmPart part) => costOf(part, levelOf(part).value);

  bool canUpgrade(ArmPart part) =>
      !atMarkCeiling(part) && _stock.has(ResourceId.credits, upgradeCost(part));

  /// Buys [levels] of [part], stopping at the cap or at what the store
  /// can pay for -- whichever comes first. Returns how many landed.
  int upgrade(ArmPart part, {int levels = 1}) {
    final signal = levelOf(part);
    final ceiling = ceilingOf(part);
    var bought = 0;
    while (bought < levels && signal.value < ceiling) {
      final price = costOf(part, signal.value);
      if (!_stock.spend(ResourceId.credits, price)) break;
      signal.value = signal.value + 1;
      bought++;
    }
    return bought;
  }

  /// How many levels of [part] the store could pay for right now,
  /// memoised on (purse, level): read on every rebuild of the part card,
  /// and a bottomless purse makes the walk a thousand prices long.
  int affordableLevels(ArmPart part) {
    final purse = _stock.amount(ResourceId.credits);
    final level = levelOf(part).value;
    final hit = _affordable[part];
    if (hit != null && hit.purse == purse && hit.level == level) {
      return hit.count;
    }
    final count = walkAffordable(
      purse: purse,
      level: level,
      cap: ceilingOf(part),
      limit: maxPartLevel,
      price: (at) => costOf(part, at),
    );
    _affordable[part] = (purse: purse, level: level, count: count);
    return count;
  }

  final Map<ArmPart, ({BigDouble purse, int level, int count})> _affordable =
      {};

  // ----------------------------------------------------------------- save

  /// Levels only when moved; marks and peaks always -- an absent mark
  /// would read as the level's walked one, handing a rebuild nobody
  /// performed.
  Map<String, Object?> toJson() => {
    if (bitLevel.value != 0) 'bit': bitLevel.value,
    if (driveLevel.value != 0) 'drive': driveLevel.value,
    if (supplyLevel.value != 0) 'supply': supplyLevel.value,
    'bitMark': bitMark.value,
    'driveMark': driveMark.value,
    'supplyMark': supplyMark.value,
    'bitPeak': bitPeak.value,
    'drivePeak': drivePeak.value,
    'supplyPeak': supplyPeak.value,
  };

  void readJson(Object? json) {
    if (json is! Map) {
      for (final part in ArmPart.values) {
        levelOf(part).value = 0;
        markOf(part).value = 0;
        peakOf(part).value = 0;
      }
      return;
    }
    bitLevel.value = _int(json['bit'], 0).clamp(0, maxPartLevel);
    driveLevel.value = _int(json['drive'], 0).clamp(0, maxPartLevel);
    supplyLevel.value = _int(json['supply'], 0).clamp(0, maxPartLevel);
    // A save from before the marks were kept knows only where the parts
    // stand, and standing at a level is proof enough of having been built
    // that far. A mark ABOVE what its level's threshold allows melts DOWN
    // to the walked one (safeguard six): the ladder's numbers changed,
    // and nobody inherits a mark they have not reached.
    for (final part in ArmPart.values) {
      final level = levelOf(part).value;
      final built = generationOf(level);
      final mark = _int(json['${part.name}Mark'], built).clamp(0, lastMark);
      markOf(part).value = mark < built ? mark : built;
      // A peak above the last mark cannot be a mark: it is a level,
      // written by a build that kept peaks in levels. Convert rather than
      // clamp -- clamping turned every such save into "Mk V already seen".
      final stored = _int(json['${part.name}Peak'], markOf(part).value);
      final seen = (stored > lastMark ? generationOf(stored) : stored).clamp(
        0,
        lastMark,
      );
      peakOf(part).value = seen > markOf(part).value
          ? seen
          : markOf(part).value;
    }
  }

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
}
