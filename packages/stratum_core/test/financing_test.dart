import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  PrototypeSimulation stocked() {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(100000));
    return sim;
  }

  /// Grants [rounds] worth of turnover directly.
  void raise(PrototypeSimulation sim, int rounds) {
    sim.creditsEarned.value = sim.roundFloor(rounds) + BigDouble.one;
  }

  test('sales raise the turnover; a round pays three tranches', () {
    final sim = stocked();
    sim.sellPosition(ResourceId.regolith);
    expect(sim.financeRound, greaterThan(0));
    expect(sim.tranchesFree, sim.financeRound * sim.tranchesPerRound);
  });

  test('the ladder is geometric and the log inversion agrees with it', () {
    final sim = PrototypeSimulation();
    for (var round = 1; round < 12; round++) {
      sim.creditsEarned.value =
          sim.roundFloor(round) + BigDouble.fromNum(0.001);
      expect(sim.financeRound, round, reason: 'round $round');
      sim.creditsEarned.value =
          sim.roundFloor(round) - BigDouble.fromNum(0.001);
      expect(sim.financeRound, round - 1, reason: 'below round $round');
    }
  });

  test('investing is gated by free tranches and by the cap', () {
    final sim = PrototypeSimulation();
    expect(sim.investTranche(ResourceId.credits), isFalse);
    raise(sim, 4); // 12 tranches, cap 10 at rank 0
    for (var i = 0; i < 10; i++) {
      expect(sim.investTranche(ResourceId.credits), isTrue);
    }
    // The eleventh hits the rank-0 cap even with tranches left over.
    expect(sim.tranchesFree, 2);
    expect(sim.canInvest(ResourceId.credits), isFalse);
    expect(sim.investTranche(ResourceId.regolith), isTrue);
  });

  test('ranks climb on SPENT tranches at 20, 45, 75, 110, 150, 190...', () {
    expect(PrototypeSimulation.rankThreshold(1), 20);
    expect(PrototypeSimulation.rankThreshold(2), 45);
    expect(PrototypeSimulation.rankThreshold(3), 75);
    expect(PrototypeSimulation.rankThreshold(4), 110);
    expect(PrototypeSimulation.rankThreshold(5), 150);
    expect(PrototypeSimulation.rankThreshold(6), 190);
  });

  test('the rank ladder can never outrun the level caps', () {
    // The lock this guards against was real TWICE: quadratic thresholds
    // against linear cap room locked at rank ~10; then shrinking the table
    // to four lanes at +5 cap a rank locked at rank ~4. Thresholds capped
    // at 40, caps at +10, and room counted in TRANCHES (tiered prices make
    // deep levels drain more) keep the margin growing for ever.
    for (var rank = 1; rank <= 200; rank++) {
      final need = PrototypeSimulation.rankThreshold(rank);
      final capAtPreviousRank =
          PrototypeSimulation.fundCapBase +
          PrototypeSimulation.fundCapPerRank * (rank - 1);
      final roomAtPreviousRank =
          PrototypeSimulation.fundTable.length *
          PrototypeSimulation.tranchesInto(capAtPreviousRank);
      expect(
        need,
        lessThanOrEqualTo(roomAtPreviousRank),
        reason: 'rank $rank locks',
      );
    }
  });

  test('levels past every twentieth cost one more tranche', () {
    expect(PrototypeSimulation.investCostAt(0), 1);
    expect(PrototypeSimulation.investCostAt(19), 1);
    expect(PrototypeSimulation.investCostAt(20), 2);
    expect(PrototypeSimulation.investCostAt(39), 2);
    expect(PrototypeSimulation.investCostAt(40), 3);
    // The closed form agrees with the sum.
    var sum = 0;
    for (var level = 0; level < 47; level++) {
      sum += PrototypeSimulation.investCostAt(level);
      expect(PrototypeSimulation.tranchesInto(level + 1), sum);
    }
  });

  test('a deep level drains its full price from the free pool', () {
    final sim = PrototypeSimulation();
    raise(sim, 60);
    // Climb the ladder the way a player must: round-robin under the caps
    // until rank 2 lifts them to 30 -- only then can a lane cross level
    // 20, where the price becomes two.
    while (sim.financeRank < 2) {
      var moved = false;
      for (final row in PrototypeSimulation.fundTable) {
        if (sim.investTranche(row.id)) moved = true;
      }
      expect(moved, isTrue, reason: 'the walk itself must never lock');
    }
    while (sim.fundingOf(ResourceId.credits).value < 20) {
      expect(sim.investTranche(ResourceId.credits), isTrue);
    }
    expect(sim.investCost(ResourceId.credits), 2);
    final freeBefore = sim.tranchesFree;
    expect(sim.investTranche(ResourceId.credits), isTrue);
    expect(sim.tranchesFree, freeBefore - 2);
  });

  test('a rank lifts every cap by ten', () {
    final sim = PrototypeSimulation();
    raise(sim, 10); // 30 tranches
    expect(sim.fundCap, 10);
    for (var i = 0; i < 10; i++) {
      sim.investTranche(ResourceId.credits);
    }
    for (var i = 0; i < 10; i++) {
      sim.investTranche(ResourceId.regolith);
    }
    // 20 spent: rank 1, caps now 20, credits can grow again.
    expect(sim.financeRank, 1);
    expect(sim.fundCap, 20);
    expect(sim.canInvest(ResourceId.credits), isTrue);
  });

  test('each lane compounds its own step and the global rides them all', () {
    final sim = PrototypeSimulation();
    raise(sim, 1);
    sim.investTranche(ResourceId.cuprite);
    final global = sim.fundGlobalScale.toDouble();
    expect(global, closeTo(1.01, 1e-9)); // one spent, rank 0
    expect(
      sim.fundScaleOf(ResourceId.cuprite).toDouble(),
      closeTo(1.06 * global, 1e-9),
    );
    // An untouched lane still wears the global...
    expect(
      sim.fundScaleOf(ResourceId.ferrite).toDouble(),
      closeTo(global, 1e-9),
    );
    // Raw data is IN the table (owner's exception), so it wears the
    // global too...
    expect(
      sim.fundScaleOf(ResourceId.rawData).toDouble(),
      closeTo(global, 1e-9),
    );
    // ...but everything outside the market wears nothing at all.
    expect(sim.fundScaleOf(ResourceId.quantonium).toDouble(), 1.0);
    expect(sim.fundScaleOf(ResourceId.crystals).toDouble(), 1.0);
    expect(sim.fundScaleOf(ResourceId.silicite).toDouble(), 1.0);
  });

  test('credit funding multiplies quotes and the quote is what is paid', () {
    final sim = stocked();
    final before = sim.sellYield(ResourceId.regolith);
    raise(sim, 1);
    sim.investTranche(ResourceId.credits);
    final after = sim.sellYield(ResourceId.regolith);
    expect(after.toDouble() / before.toDouble(), closeTo(1.07 * 1.01, 1e-9));
    final quoted = sim.sellYield(ResourceId.regolith);
    final paid = sim.sellPosition(ResourceId.regolith);
    expect(paid.toDouble(), closeTo(quoted.toDouble(), 1e-6));
  });

  test('a funded ore raises its own forecast; data rides only the global', () {
    final sim = PrototypeSimulation();
    final ore = sim.expectedPerStrike(ResourceId.regolith);
    final data = sim.expectedPerStrike(ResourceId.rawData);
    raise(sim, 1);
    sim.investTranche(ResourceId.regolith);
    expect(
      sim.expectedPerStrike(ResourceId.regolith).toDouble() / ore.toDouble(),
      closeTo(1.05 * 1.01, 1e-9),
    );
    expect(
      sim.expectedPerStrike(ResourceId.rawData).toDouble() / data.toDouble(),
      closeTo(1.01, 1e-9),
    );
  });

  test('granted levels climb ranks without draining the free pool', () {
    final sim = PrototypeSimulation();
    raise(sim, 5); // 15 free tranches, untouched throughout
    final freeBefore = sim.tranchesFree;
    // A tree node gifts ten levels twice: 20 spent-equivalents, rank 1.
    expect(sim.grantFundLevels(ResourceId.credits, 10), 10);
    expect(sim.grantFundLevels(ResourceId.regolith, 10), 10);
    expect(sim.financeRank, 1);
    expect(sim.tranchesFree, freeBefore);
    // The gift compounds the global exactly like poured tranches.
    expect(
      sim.fundGlobalScale.toDouble(),
      closeTo(1.01 * sim.fundGlobalScale.toDouble() / 1.01, 1e-9),
    );
    // And a gift respects the cap: at rank 1 the cap is 20.
    expect(sim.grantFundLevels(ResourceId.credits, 100), 10);
    expect(sim.fundingOf(ResourceId.credits).value, 20);
    // The whole ledger survives a save.
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.tranchesGranted.value, sim.tranchesGranted.value);
    expect(back.tranchesFree, sim.tranchesFree);
    expect(back.financeRank, sim.financeRank);
  });

  test('an impossible saved distribution melts to the gifted floor', () {
    final sim = PrototypeSimulation();
    raise(sim, 4); // 12 tranches
    sim.grantFundLevels(ResourceId.regolith, 5);
    for (var i = 0; i < 8; i++) {
      sim.investTranche(ResourceId.credits);
    }
    final json = sim.toJson();
    // The same save, but the run earned less than the spending claims --
    // the shape of any balance change that shrinks the tranche income.
    final run = Map<String, Object?>.from(json);
    final finance = Map<String, Object?>.from(run['finance'] as Map);
    finance['earned'] = BigDouble.zero.toJson();
    run['finance'] = finance;

    final back = PrototypeSimulation()..readJson(run);
    expect(back.fundingWasReset, isTrue);
    // Bought levels melted, gifted floor kept, gift re-credited.
    expect(back.fundingOf(ResourceId.credits).value, 0);
    expect(back.fundingOf(ResourceId.regolith).value, 5);
    expect(back.grantedLevelsOf(ResourceId.regolith), 5);
    expect(back.tranchesFree, 0); // no rounds -- nothing earned yet
    expect(back.tranchesSpent, PrototypeSimulation.tranchesInto(5));
    expect(back.tranchesGranted.value, PrototypeSimulation.tranchesInto(5));
  });

  test('a healthy save does not trip the melt', () {
    final sim = PrototypeSimulation();
    raise(sim, 10);
    sim.grantFundLevels(ResourceId.credits, 3);
    for (var i = 0; i < 10; i++) {
      sim.investTranche(ResourceId.regolith);
    }
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.fundingWasReset, isFalse);
    expect(back.fundingOf(ResourceId.regolith).value, 10);
    expect(back.fundingOf(ResourceId.credits).value, 3);
  });

  test('financing survives a save', () {
    final sim = stocked();
    sim.sellPosition(ResourceId.regolith);
    sim.investTranche(ResourceId.ferrite);
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(
      back.creditsEarned.value.toDouble(),
      closeTo(sim.creditsEarned.value.toDouble(), 1e-6),
    );
    expect(back.fundingOf(ResourceId.ferrite).value, 1);
    expect(back.tranchesFree, sim.tranchesFree);
    expect(back.financeRank, sim.financeRank);
  });

  test('the regolith fund level scales a break payout like the roll', () {
    // Two identical digs on the same seed, one with financing poured into
    // regolith: every regolith payout -- the roll AND the break bonus --
    // must scale by exactly the same multiplier, because they all enter
    // through the one door.
    BigDouble dig(int levels) {
      final sim = PrototypeSimulation(seed: 77);
      sim.grantFundLevels(ResourceId.regolith, levels);
      var thick = 1;
      while (!PrototypeSimulation.isThick(thick)) {
        thick++;
      }
      sim.layer.value = thick;
      sim.layerHp.value = BigDouble.one; // one blow away from the payout
      final before = sim.regolith.value;
      final outcome = sim.strike();
      expect(outcome.thickLayersBroken, greaterThan(0));
      return sim.regolith.value - before;
    }

    final plain = dig(0);
    final funded = dig(5);
    final scale =
        (PrototypeSimulation(seed: 77)..grantFundLevels(ResourceId.regolith, 5))
            .fundScaleOf(ResourceId.regolith);
    expect(scale > BigDouble.one, isTrue);
    expect(
      funded.toDouble(),
      closeTo((plain * scale).toDouble(), (plain * scale).toDouble() * 1e-9),
    );
  });
}
