import 'dart:math' as math;

import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'affordable_walk.dart';
import 'drill_id.dart';
import 'drill_part.dart';
import 'drill_row.dart';
import 'drill_state.dart';

/// The drills: a bore of some RADIUS working the face on its own CYCLE.
/// What a drill brings up is what its blow brings up, widened by how much
/// face it covers -- one loot table, one truth, a wider sweep. This holds
/// every drill's tracks and prices; the cycle itself is the simulation's.
class DrillBank {
  DrillBank(this._stock) {
    for (final row in drillTable) {
      _yieldScales[row.id] = Computed(() {
        final r = radius(row.id);
        return BigDouble.fromNum(r * r / (drillRadiusBase * drillRadiusBase));
      }, name: 'drill yield scale ${row.id.name}');
    }
  }

  final Stockpile _stock;

  /// The bore every drill starts with, in metres.
  static const double drillRadiusBase = 5;

  /// What one level of the radius track adds. Additive on the RADIUS, so
  /// the area it buys grows as pi(2r+1) -- the same level is worth more
  /// the wider the bore already is, which is the whole point of the track.
  static const double drillRadiusPerLevel = 1;

  /// What one level of the drive track cuts off the CURRENT interval. The
  /// track is finite: it ends where the interval meets
  /// [drillIntervalFloor], and its whole lifetime value is base / floor
  /// whatever this number is -- the percentage only sets how many levels
  /// that value is spread over.
  static const double drillSpeedStep = 0.01;

  /// No drill cycles faster than this. A floor rather than an asymptote,
  /// so the timer can never outrun the frame.
  static const double drillIntervalFloor = 2;

  /// The calibration track: one number buying both odds.
  static const double drillCritBase = 0.05;
  static const double drillCritPerLevel = 0.002;
  static const double drillCritPower = 1.20;
  static const double drillEchoBase = 0.01;
  static const double drillEchoPerLevel = 0.0005;

  /// Every drill in the game, in the order they open.
  ///
  /// A table rather than a branch per drill: a new drill is a row here
  /// plus its resource, not a new field threaded through every place
  /// that counts.
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
  final Map<DrillId, DrillState> states = {
    for (final row in drillTable) row.id: DrillState(row.id),
  };

  DrillState drill(DrillId id) => states[id]!;

  bool owned(DrillId id) => id == DrillId.regolith;

  /// The bore, in metres.
  double radius(DrillId id) =>
      drillRadiusBase + drillRadiusPerLevel * drill(id).radius.value;

  /// The face it covers, in square metres.
  double area(DrillId id) {
    final r = radius(id);
    return math.pi * r * r;
  }

  /// How much more face than a fresh bore -- and so how much more its
  /// blow brings up. Exactly 1 at level 0, which is what makes wiring it
  /// safe.
  final Map<DrillId, Computed<BigDouble>> _yieldScales = {};

  BigDouble yieldScale(DrillId id) => _yieldScales[id]!.value;

  /// Seconds between cycles, never below the floor.
  double interval(DrillId id) {
    final base = rowFor(id).intervalBase;
    final cut = math.pow(1 - drillSpeedStep, drill(id).drive.value).toDouble();
    final paced = base * cut;
    return paced < drillIntervalFloor ? drillIntervalFloor : paced;
  }

  /// The last drive level that still buys anything.
  ///
  /// Sold levels past this would cost real resources for nothing, so the
  /// track simply ends here instead of clamping in silence.
  static int driveCap(DrillId id) {
    final base = rowFor(id).intervalBase;
    if (base <= drillIntervalFloor) return 0;
    final n =
        math.log(drillIntervalFloor / base) / math.log(1 - drillSpeedStep);
    return n.ceil();
  }

  double critChance(DrillId id) =>
      drillCritBase + drillCritPerLevel * drill(id).calibration.value;

  double echoChance(DrillId id) =>
      drillEchoBase + drillEchoPerLevel * drill(id).calibration.value;

  static BigDouble costOf(DrillPart part, int level) {
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

  BigDouble upgradeCost(DrillId id, DrillPart part) =>
      costOf(part, drill(id).levelOf(part).value);

  /// Where a track stops. Radius and calibration run on; the drive track
  /// is finite by construction.
  int cap(DrillId id, DrillPart part) =>
      part == DrillPart.drive ? driveCap(id) : 1 << 30;

  bool atCap(DrillId id, DrillPart part) =>
      drill(id).levelOf(part).value >= cap(id, part);

  bool canUpgrade(DrillId id, DrillPart part) =>
      owned(id) &&
      !atCap(id, part) &&
      _stock.has(ResourceId.credits, upgradeCost(id, part));

  /// Buys up to [levels] of [part], stopping at the cap or at what the
  /// store can pay for. Returns how many actually landed.
  int upgrade(DrillId id, DrillPart part, {int levels = 1}) {
    if (!owned(id)) return 0;
    final signal = drill(id).levelOf(part);
    final ceiling = cap(id, part);
    var bought = 0;
    while (bought < levels && signal.value < ceiling) {
      if (!_stock.spend(ResourceId.credits, costOf(part, signal.value))) {
        break;
      }
      signal.value = signal.value + 1;
      bought++;
    }
    return bought;
  }

  /// How many levels of [part] the store could pay for right now,
  /// memoised on (purse, level) -- read on every rebuild of the row.
  int affordableLevels(DrillId id, DrillPart part) {
    final purse = _stock.amount(ResourceId.credits);
    final level = drill(id).levelOf(part).value;
    final hit = _affordable[(id, part)];
    if (hit != null && hit.purse == purse && hit.level == level) {
      return hit.count;
    }
    final count = walkAffordable(
      purse: purse,
      level: level,
      cap: cap(id, part),
      limit: 1000,
      price: (at) => costOf(part, at),
    );
    _affordable[(id, part)] = (purse: purse, level: level, count: count);
    return count;
  }

  final Map<(DrillId, DrillPart), ({BigDouble purse, int level, int count})>
  _affordable = {};

  /// Only the levels that moved, per drill that moved.
  Map<String, Object?> toJson() => {
    for (final row in drillTable)
      if (DrillPart.values.any((p) => drill(row.id).levelOf(p).value != 0))
        row.id.name: {
          for (final part in DrillPart.values)
            if (drill(row.id).levelOf(part).value != 0)
              part.name: drill(row.id).levelOf(part).value,
        },
  };

  void readJson(Object? json) {
    for (final row in drillTable) {
      final held = json is Map ? json[row.id.name] : null;
      final state = drill(row.id);
      for (final part in DrillPart.values) {
        final stored = held is Map ? _int(held[part.name]) : 0;
        state.levelOf(part).value = stored.clamp(0, cap(row.id, part));
      }
    }
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
