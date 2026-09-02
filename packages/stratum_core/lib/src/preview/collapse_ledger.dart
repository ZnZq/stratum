import 'dart:math' as math;

import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'acknowledged_clock.dart';

/// Data, cubes and the collapse wall: what a run's substrate compiles
/// into, how many racks it fills, and how the gate melts with drift on
/// the acknowledged clock. Owns every number the datacentre reads.
class CollapseLedger {
  CollapseLedger(this._stock, this._clock) {
    walletEarned = Computed(
      () => rawData.value * BigDouble.fromNum(compileRate / rawPerCube),
      name: 'wallet earned',
    );
  }

  final Stockpile _stock;
  final AcknowledgedClock _clock;

  /// What this simulation has dug up and not yet compiled: a view on the
  /// registry, a mined resource like the ores.
  Signal<BigDouble> get rawData => _stock.signal(ResourceId.rawData);

  /// Raw data of the whole cycle, across restarts. Feeds the wallet
  /// function; only a collapse resets it.
  final Signal<BigDouble> cycleData = Signal(
    BigDouble.zero,
    name: 'cycle data',
  );

  /// Banked data not yet spent on the simulation tree.
  final Signal<BigDouble> dataWallet = Signal(
    BigDouble.zero,
    name: 'data wallet',
  );

  /// How well the centre compiles. Each level lifts the rate; the JSON
  /// key is still 'exponent' from when compilation was a power, and
  /// renaming it would cost a migration for a number nobody has spent.
  final Signal<int> compilerLevel = Signal(0, name: 'compiler level');

  /// Collapses performed, ever.
  final Signal<int> collapses = Signal(0, name: 'collapses');

  /// How many racks the centre can actually use, 1 to
  /// [maxPendingCollapses]. Starts at one: holding five collapses at once
  /// is capacity the player buys, not something the wall comes with.
  final Signal<int> servers = Signal(1, name: 'servers');

  int get unlockedServers =>
      servers.value.clamp(1, maxPendingCollapses).toInt();

  /// When this cycle began, on the ACKNOWLEDGED clock (seenNow units, not
  /// epoch ms). -1 until the app stamps it.
  final Signal<int> cycleStartMs = Signal(-1, name: 'cycle start');

  /// How much substrate one cube is compiled from.
  ///
  /// A plain divisor, not a power. A sublinear curve made splitting a
  /// haul across many short runs pay more than one long one, so the
  /// optimum was to restart as often as the gate allowed. Dividing is
  /// neutral: the same substrate compiles to the same cubes however many
  /// restarts it took.
  static const double rawPerCube = 1000;

  /// What one compiler level adds to the rate.
  static const double compilerStep = 0.05;

  /// What ONE collapse costs, in cubes -- cubes rather than the raw
  /// substrate behind them, so the collapse gauge and the restart preview
  /// read the same figure. The compiler upgrade therefore lifts cubes AND
  /// brings the collapse nearer: one lever, two effects. PROVISIONAL.
  static final BigDouble collapseThresholdBase = BigDouble.fromNum(1.5e5);

  /// How many collapses the centre can hold at once -- one per rack.
  /// Past the fifth there is nowhere to put the cubes, so leaving the
  /// wall full is a real loss rather than a safe idle.
  static const int maxPendingCollapses = 5;

  /// What each rack costs over the one before it: CUMULATIVE totals, so
  /// a run worth twice the base fills the first rack and makes a start
  /// on the second. PROVISIONAL.
  static const double collapseRackGrowth = 2.6;

  /// What the gate is multiplied by per collapse already performed.
  /// PROVISIONAL.
  static const double collapseThresholdGrowth = 4;

  /// Drift: the threshold melts by this factor per wall-clock day, online
  /// and offline alike.
  static const double collapseDriftPerDay = 0.97;

  /// How many days of drift a cycle accrues before the melt stops. At 30
  /// days the wall stands at 40% of base -- less than the x4 a single
  /// collapse adds, so waiting can never outrun the ladder.
  static const double collapseDriftCapDays = 30;

  /// Cycles CLOSED, not the ordinal of the one being played.
  int get cycleNumber => collapses.value;

  /// How many collapses are ready to be taken right now, 0 to
  /// [maxPendingCollapses]. Each is worth a collapse point and closes a
  /// cycle, so taking three at once is three of both.
  int pendingCollapses(int nowMs) {
    var full = 0;
    for (var rack = 0; rack < unlockedServers; rack++) {
      if (!walletEarned.value.gteWithTolerance(collapseCost(rack, nowMs))) {
        break;
      }
      full++;
    }
    return full;
  }

  /// The cubes at which [rack] (0-based) is full -- a running total, so
  /// rack 2 being full means rack 0 and rack 1 are too.
  BigDouble collapseCost(int rack, int nowMs) =>
      collapseThreshold(nowMs) *
      BigDouble.fromNum(math.pow(collapseRackGrowth, rack).toDouble());

  /// How full one rack is, 0 to 1. A rack fills from where the one before
  /// it finished, so the wall reads left to right without gaps.
  double rackFill(int rack, int nowMs) {
    final to = collapseCost(rack, nowMs);
    final from = rack == 0 ? BigDouble.zero : collapseCost(rack - 1, nowMs);
    final span = to - from;
    if (span <= BigDouble.zero) return 0;
    return ((walletEarned.value - from) / span).toDouble().clamp(0.0, 1.0);
  }

  /// Cubes per unit of substrate, before the divisor.
  double get compileRate => 1 + compilerStep * compilerLevel.value;

  /// What the current simulation would compile into.
  late final Computed<BigDouble> walletEarned;

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

  /// Days of drift this cycle has banked, capped at
  /// [collapseDriftCapDays]. Measured on the ACKNOWLEDGED clock, so an
  /// absence past the cap melts the gate by two days, not by however long
  /// the player was gone. A negative start means the app has not stamped
  /// the cycle yet.
  double driftDays(int nowMs) {
    final start = cycleStartMs.value;
    if (start < 0) return 0;
    final seen = _clock.seenNow(nowMs);
    if (seen <= start) return 0;
    final days = (seen - start) / Duration.millisecondsPerDay;
    return days > collapseDriftCapDays ? collapseDriftCapDays : days;
  }

  /// How far through the drift window the cycle is, 0 to 1.
  double driftProgress(int nowMs) => driftDays(nowMs) / collapseDriftCapDays;

  /// How much of the gate the drift has already eaten, 0 to 1.
  double driftDiscount(int nowMs) =>
      1 - math.pow(collapseDriftPerDay, driftDays(nowMs)).toDouble();

  /// Books a haul of substrate: into the store like any resource, and
  /// into the cycle's running total, which is what the wallet is
  /// compressed from. The cycle total is kept apart because it must
  /// survive a Restart: the store is wiped, the cycle's record is not.
  void record(BigDouble gained) {
    if (gained.isZero) return;
    _stock.add(ResourceId.rawData, gained);
    cycleData.value = cycleData.value + gained;
  }

  // ----------------------------------------------------------------- save

  /// The 'data' section: only departures from a fresh run. Collapses and
  /// servers are top-level keys of the run and written by its owner.
  Map<String, Object?> toJson() => {
    if (!rawData.value.isZero) 'raw': rawData.value.toJson(),
    if (!cycleData.value.isZero) 'gross': cycleData.value.toJson(),
    if (!dataWallet.value.isZero) 'wallet': dataWallet.value.toJson(),
    if (compilerLevel.value != 0) 'exponent': compilerLevel.value,
    if (cycleStartMs.value != -1) 'cycleStartSeen': cycleStartMs.value,
  };

  void readJson(Object? json) {
    if (json is! Map) {
      rawData.value = BigDouble.zero;
      cycleData.value = BigDouble.zero;
      dataWallet.value = BigDouble.zero;
      compilerLevel.value = 0;
      cycleStartMs.value = -1;
      return;
    }
    rawData.value = _big(json['raw']);
    cycleData.value = _big(json['gross']);
    dataWallet.value = _big(json['wallet']);
    compilerLevel.value = _int(json['exponent'], 0);
    // Older saves stamped the cycle in EPOCH ms under 'cycleStartMs'; the
    // acknowledged clock cannot honour that unit, so their drift restarts
    // once rather than being misread as decades of melt.
    cycleStartMs.value = _int(json['cycleStartSeen'], -1);
  }

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

  static BigDouble _big(Object? v) =>
      v is String ? (BigDouble.tryParse(v) ?? BigDouble.zero) : BigDouble.zero;
}
