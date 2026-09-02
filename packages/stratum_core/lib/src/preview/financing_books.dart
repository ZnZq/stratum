import 'dart:math' as math;

import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';

/// Financing: the level-based meta system raised against lifetime
/// turnover. The AI proves turnover, the backer opens the next ROUND;
/// each round pays TRANCHES, tranches buy levels on the funded lanes, and
/// every tranche spent (and every rank climbed) compounds a global
/// multiplier on top. Every link is a Computed so that whatever moves --
/// a level poured, a sale landing, a gifted tranche -- invalidates
/// exactly its dependents: [scaleOf] sits on the strike's hot path five
/// lanes at a time.
class FinancingBooks {
  FinancingBooks(this._stock) {
    _round = Computed(() {
      final earned = creditsEarned.value;
      if (earned <= BigDouble.zero) return 0;
      final g = BigDouble.fromNum(roundCostGrowth);
      final ratio =
          earned * (g - BigDouble.one) / roundCostBase + BigDouble.one;
      final rounds = (ratio.ln() / math.log(roundCostGrowth)).floorToDouble();
      return rounds < 0 ? 0 : rounds.toInt();
    }, name: 'finance round');
    _spent = Computed(() {
      var spent = 0;
      for (final row in fundTable) {
        spent += tranchesInto(_funding[row.id]!.value);
      }
      return spent;
    }, name: 'tranches spent');
    _rank = Computed(() {
      var rank = 0;
      while (_spent.value >= rankThreshold(rank + 1)) {
        rank++;
      }
      return rank;
    }, name: 'finance rank');
    _cap = Computed(
      () => fundCapBase + fundCapPerRank * _rank.value,
      name: 'fund cap',
    );
    _free = Computed(() {
      final free =
          _round.value * tranchesPerRound +
          tranchesGranted.value -
          _spent.value;
      return free < 0 ? 0 : free;
    }, name: 'tranches free');
    _globalScale = Computed(
      () =>
          BigDouble.fromNum(fundSpentStep).pow(_spent.value.toDouble()) *
          BigDouble.fromNum(fundRankStep).pow(_rank.value.toDouble()),
      name: 'fund global scale',
    );
    for (final row in fundTable) {
      _scales[row.id] = Computed(
        () =>
            BigDouble.fromNum(row.step)
                .pow(_funding[row.id]!.value.toDouble()) *
            _globalScale.value,
        name: 'fund scale ${row.id.name}',
      );
    }
  }

  final Stockpile _stock;

  /// What the first round costs; every next costs [roundCostGrowth] more.
  /// PROVISIONAL, like every constant here.
  static final BigDouble roundCostBase = BigDouble.fromNum(500);
  static const double roundCostGrowth = 1.9;

  /// Each fundable resource and its per-level step. THE RULE: financing
  /// funds what earns credits -- the price list plus credits themselves --
  /// plus ONE owner's exception: raw data, at the slowest step, because
  /// the substrate is the product the simulation is mined FOR. Quantonium
  /// stays with the trees. Steps UNEQUAL on purpose (owner's numbers).
  /// PROVISIONAL.
  static const List<({ResourceId id, double step})> fundTable = [
    (id: ResourceId.credits, step: 1.07),
    (id: ResourceId.regolith, step: 1.05),
    (id: ResourceId.cuprite, step: 1.06),
    (id: ResourceId.ferrite, step: 1.05),
    (id: ResourceId.rawData, step: 1.01),
  ];

  /// Tranches paid per closed round. A future tree node raises it.
  int get tranchesPerRound => 3;

  /// The global compounding for every tranche SPENT and every rank climbed.
  static const double fundSpentStep = 1.01;
  static const double fundRankStep = 1.02;

  /// How many more levels every multiplier gains per rank. TEN, not the
  /// five first asked for: cap room grows lanes×this per rank against a
  /// threshold step that settles at 40, and with four lanes a five left
  /// nowhere to spend past rank four -- the same lock the thresholds were
  /// already capped against, reopened from the other side.
  static const int fundCapBase = 10;
  static const int fundCapPerRank = 10;

  /// Credits earned over this simulation's whole life -- income only,
  /// never reduced by spending. This is what rounds are raised against.
  final Signal<BigDouble> creditsEarned = Signal(
    BigDouble.zero,
    name: 'credits earned',
  );

  final Map<ResourceId, Signal<int>> _funding = {
    for (final row in fundTable)
      row.id: Signal(0, name: 'funding ${row.id.name}'),
  };

  Signal<int> fundingOf(ResourceId id) => _funding[id]!;

  static double fundStep(ResourceId id) =>
      fundTable.firstWhere((row) => row.id == id).step;

  /// Rounds closed so far, from lifetime turnover. Geometric ladder:
  /// total to reach round n is base·(g^n − 1)/(g − 1), inverted with a
  /// log so a qa-scale turnover does not loop a million times.
  late final Computed<int> _round;
  int get round => _round.value;

  /// Lifetime turnover at which [round] is reached.
  BigDouble roundFloor(int round) =>
      roundCostBase *
      (BigDouble.fromNum(roundCostGrowth).pow(round.toDouble()) -
          BigDouble.one) /
      BigDouble.fromNum(roundCostGrowth - 1);

  /// What the NEXT round still wants, and how far along it is.
  BigDouble get nextRoundCost =>
      roundCostBase * BigDouble.fromNum(roundCostGrowth).pow(round.toDouble());

  double get roundProgress {
    final into = creditsEarned.value - roundFloor(round);
    if (into <= BigDouble.zero) return 0;
    final frac = (into / nextRoundCost).toDouble();
    return frac > 1 ? 1 : frac;
  }

  /// What buying the NEXT level of a lane costs, in tranches: one for the
  /// first twenty levels, two for the next twenty, and so on. Deep levels
  /// cost more -- and, through the spent-multiplier, also pump the global
  /// harder per level: the price is its own compensation.
  static int investCostAt(int level) => 1 + level ~/ 20;

  int investCost(ResourceId id) => investCostAt(_funding[id]!.value);

  /// Tranches sunk into [levels] of one lane, price tiers included.
  /// Closed form of summing [investCostAt] over 0..levels-1.
  static int tranchesInto(int levels) {
    final blocks = levels ~/ 20;
    final rest = levels % 20;
    return 10 * blocks * (blocks + 1) + rest * (blocks + 1);
  }

  /// Tranches ever invested, whatever they were invested in -- COST-
  /// weighted, so a deep level counts for what it actually drained. This
  /// is what ranks are climbed on and what the global spent-multiplier
  /// compounds from: the backer rewards commitment, not hoarding.
  late final Computed<int> _spent;
  int get tranchesSpent => _spent.value;

  /// Tranches granted outright -- by a tree node that gifts levels, or any
  /// future source. Counted as both given AND spent, so a gift climbs
  /// ranks and pumps the global exactly like poured tranches, without
  /// silently draining the player's own free pool. A Signal, not a field:
  /// the free pool depends on it, and a grant must invalidate that chain.
  final Signal<int> tranchesGranted = Signal(0, name: 'tranches granted');

  /// Gifted levels per lane, remembered apart from bought ones: when a
  /// balance change makes a saved distribution impossible, the reset
  /// melts only what the player poured -- gifts are the floor it melts
  /// down to.
  final Map<ResourceId, int> _grantedLevels = {
    for (final row in fundTable) row.id: 0,
  };

  int grantedLevelsOf(ResourceId id) => _grantedLevels[id] ?? 0;

  /// Set by [readJson] when it had to melt an impossible distribution, so
  /// the app can tell the player to redistribute. Cleared by the reader.
  bool wasReset = false;

  /// Whether the loaded books balance: no lane above its cap, and the
  /// free pool not in the negative. A save from a build with different
  /// prices, tranche pay or thresholds can violate either.
  bool get _booksBalance {
    if (round * tranchesPerRound + tranchesGranted.value - tranchesSpent < 0) {
      return false;
    }
    for (final row in fundTable) {
      if (_funding[row.id]!.value > cap) return false;
    }
    return true;
  }

  /// Melts every lane down to its gifted floor and re-credits the gifts
  /// at today's prices. Free tranches come back in full for the player to
  /// pour again -- correctly this time.
  void _reset() {
    var granted = 0;
    for (final row in fundTable) {
      final floor = _grantedLevels[row.id] ?? 0;
      _funding[row.id]!.value = floor;
      granted += tranchesInto(floor);
    }
    tranchesGranted.value = granted;
    wasReset = true;
  }

  late final Computed<int> _free;
  int get tranchesFree => _free.value;

  /// Gifts [levels] of [id], cap-clamped, at no cost to the free pool:
  /// each level's tiered price is credited to [tranchesGranted] as it is
  /// spent. Returns how many levels actually landed.
  int grantLevels(ResourceId id, int levels) {
    final signal = _funding[id]!;
    var landed = 0;
    while (landed < levels && signal.value < cap) {
      tranchesGranted.value =
          tranchesGranted.value + investCostAt(signal.value);
      signal.value = signal.value + 1;
      landed++;
    }
    _grantedLevels[id] = (_grantedLevels[id] ?? 0) + landed;
    return landed;
  }

  /// What climbing to rank [rank] costs in TOTAL tranches spent.
  ///
  /// The step walks 20, 25, 30, 35, 40 and then stays at 40 -- capped on
  /// purpose. Uncapped it grew quadratically against level caps that grow
  /// linearly, and past rank ~10 there was nowhere left to spend enough:
  /// a hard lock by arithmetic. Flat steps keep both lines linear, with a
  /// margin of 50 tranches for ever (pinned by test).
  static int rankThreshold(int rank) {
    var total = 0;
    for (var step = 1; step <= rank; step++) {
      final increment = step < 5 ? 15 + 5 * step : 40;
      total += increment;
    }
    return total;
  }

  /// The financing rank: how far the SPENDING has climbed.
  late final Computed<int> _rank;
  int get rank => _rank.value;

  /// How far along the next rank's requirement the spending is, 0 to 1.
  double get rankProgress {
    final floor = rankThreshold(rank);
    final ceiling = rankThreshold(rank + 1);
    if (ceiling <= floor) return 0;
    return ((tranchesSpent - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  }

  /// Where every multiplier's level stops at the current rank.
  late final Computed<int> _cap;
  int get cap => _cap.value;

  bool canInvest(ResourceId id) =>
      tranchesFree >= investCost(id) && _funding[id]!.value < cap;

  bool invest(ResourceId id) {
    if (!canInvest(id)) return false;
    final signal = _funding[id]!;
    signal.value = signal.value + 1;
    return true;
  }

  /// The global compounding: every spent tranche and every rank multiply
  /// EVERY funded lane, whatever the tranche was spent on.
  late final Computed<BigDouble> _globalScale;
  BigDouble get globalScale => _globalScale.value;

  /// The effective multiplier a resource's income wears -- one cached
  /// Computed per lane, because the strike loot reads all of them on
  /// every blow. A lane outside the table is untouched: not even the
  /// global rides it -- prestige fuel answers to the trees, not to the
  /// backer.
  final Map<ResourceId, Computed<BigDouble>> _scales = {};

  BigDouble scaleOf(ResourceId id) => _scales[id]?.value ?? BigDouble.one;

  /// Every credit income lands here, whatever sold it: the wallet gets
  /// the money, the ladder gets the proof of turnover.
  void earn(BigDouble paid) {
    _stock.add(ResourceId.credits, paid);
    creditsEarned.value = creditsEarned.value + paid;
  }

  Map<String, Object?> toJson() => {
    'earned': creditsEarned.value.toJson(),
    if (tranchesGranted.value != 0) 'granted': tranchesGranted.value,
    for (final row in fundTable)
      if ((_grantedLevels[row.id] ?? 0) != 0)
        'granted.${row.id.name}': _grantedLevels[row.id],
    for (final row in fundTable)
      if (_funding[row.id]!.value != 0) row.id.name: _funding[row.id]!.value,
  };

  /// Reads the section, or resets to a fresh run when there is none. A
  /// distribution this build's numbers cannot account for -- prices moved,
  /// the tranche pay shrank, thresholds shifted -- is not carried as a
  /// debt the player never took: it melts to the gifted floor and the
  /// tranches come back to be poured again (safeguard six).
  void readJson(Object? json) {
    if (json is! Map) {
      creditsEarned.value = BigDouble.zero;
      tranchesGranted.value = 0;
      for (final row in fundTable) {
        _funding[row.id]!.value = 0;
        _grantedLevels[row.id] = 0;
      }
      return;
    }
    final earned = json['earned'];
    creditsEarned.value = earned is String
        ? (BigDouble.tryParse(earned) ?? BigDouble.zero)
        : BigDouble.zero;
    tranchesGranted.value = _int(json['granted']);
    // Keys from the three-line era (extraction/telemetry/sales) simply
    // miss: those tranches come back as free ones and are re-poured.
    for (final row in fundTable) {
      _funding[row.id]!.value = _int(json[row.id.name]);
      _grantedLevels[row.id] = _int(json['granted.${row.id.name}']);
    }
    if (!_booksBalance) _reset();
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
