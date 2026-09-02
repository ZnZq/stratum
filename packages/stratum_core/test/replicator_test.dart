import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  const second = 1000;
  // Zero epoch is the acknowledged clock's never-observed sentinel.
  const t0 = 60 * second;
  final toll = PrototypeSimulation.replicatorUnlockCost(ResourceId.cuprum);
  // The machine's cycle: the craft time stretched by the tier factor.
  final base =
      craftRecipeOf(ResourceId.cuprum)!.baseSeconds *
      PrototypeSimulation.replicatorDurationFactor(ResourceId.cuprum);

  /// A bench-made pile big enough to pay the toll, quantonium included.
  PrototypeSimulation stocked() {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(ResourceId.cuprum, BigDouble.fromNum(10000));
    sim.stock.add(ResourceId.quantonium, BigDouble.fromNum(100000));
    sim.syncReplicator(t0);
    return sim;
  }

  double cuprum(PrototypeSimulation sim) =>
      sim.stock.amount(ResourceId.cuprum).toDouble();

  test('only crafted goods are replicable', () {
    expect(PrototypeSimulation.replicableIds, [
      for (final row in craftTable) row.output,
    ]);
    expect(
      PrototypeSimulation.replicableIds.contains(ResourceId.regolith),
      isFalse,
    );
  });

  test('the toll is priced by the tier, and so is the cycle yield', () {
    expect(PrototypeSimulation.replicatorUnlockCost(ResourceId.cuprum), 5000);
    expect(PrototypeSimulation.replicatorUnlockCost(ResourceId.frame), 2500);
    expect(PrototypeSimulation.replicatorUnlockCost(ResourceId.chip), 750);
    expect(PrototypeSimulation.replicatorBaseYield(ResourceId.cuprum), 100);
    expect(PrototypeSimulation.replicatorBaseYield(ResourceId.frame), 50);
    expect(PrototypeSimulation.replicatorBaseYield(ResourceId.chip), 5);
    expect(PrototypeSimulation.replicatorDurationFactor(ResourceId.cuprum), 2);
    expect(PrototypeSimulation.replicatorDurationFactor(ResourceId.frame), 4);
    expect(PrototypeSimulation.replicatorDurationFactor(ResourceId.chip), 8);
    expect(PrototypeSimulation.replicatorAmountStep(ResourceId.cuprum), 10);
    expect(PrototypeSimulation.replicatorAmountStep(ResourceId.frame), 5);
    expect(PrototypeSimulation.replicatorAmountStep(ResourceId.chip), 1);
    expect(PrototypeSimulation.replicatorUnlockQuant(ResourceId.cuprum), 2500);
    expect(PrototypeSimulation.replicatorUnlockQuant(ResourceId.frame), 5000);
    expect(PrototypeSimulation.replicatorUnlockQuant(ResourceId.chip), 10000);
  });

  test('unlocking costs the toll in the resource itself PLUS quantonium', () {
    final sim = stocked();
    final quant = PrototypeSimulation.replicatorUnlockQuant(ResourceId.cuprum);
    expect(sim.canUnlockReplicator(ResourceId.cuprum), isTrue);
    expect(sim.unlockReplicator(ResourceId.cuprum), isTrue);
    expect(cuprum(sim), closeTo(10000 - toll, 1e-9));
    expect(
      sim.stock.amount(ResourceId.quantonium).toDouble(),
      closeTo(100000 - quant, 1e-9),
    );
    // Paying twice is refused.
    expect(sim.unlockReplicator(ResourceId.cuprum), isFalse);
  });

  test('no quantonium -- no unlock, and no track levels either', () {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(ResourceId.cuprum, BigDouble.fromNum(1e6));
    sim.syncReplicator(t0);
    expect(sim.canUnlockReplicator(ResourceId.cuprum), isFalse);
    expect(sim.unlockReplicator(ResourceId.cuprum), isFalse);
    // Grant just enough for the unlock, then run dry again.
    sim.stock.add(
      ResourceId.quantonium,
      BigDouble.fromNum(
        PrototypeSimulation.replicatorUnlockQuant(ResourceId.cuprum),
      ),
    );
    expect(sim.unlockReplicator(ResourceId.cuprum), isTrue);
    expect(sim.upgradeReplicatorSpeed(ResourceId.cuprum), isFalse);
    expect(sim.upgradeReplicatorAmount(ResourceId.cuprum), isFalse);
    expect(cuprum(sim), closeTo(1e6 - toll, 1e-9));
  });

  test('a machine pays whole cycles of its base craft time', () {
    final sim = stocked();
    sim.unlockReplicator(ResourceId.cuprum);
    final start = cuprum(sim);
    // Ten and a half cycles: ten pay out, the half stays banked.
    sim.syncReplicator(t0 + (10.5 * base * second).round());
    expect(cuprum(sim), closeTo(start + 10 * 100, 1e-6));
    expect(
      sim.replicatorFractionOf(ResourceId.cuprum).value,
      closeTo(0.5, 1e-6),
    );
  });

  test('a speed level shaves one percent off the CURRENT time', () {
    final sim = stocked();
    sim.unlockReplicator(ResourceId.cuprum);
    expect(sim.replicatorSeconds(ResourceId.cuprum), closeTo(base, 1e-9));
    final before = sim.replicatorSeconds(ResourceId.cuprum);
    sim.replicatorSpeedOf(ResourceId.cuprum).value = 1;
    expect(
      sim.replicatorSeconds(ResourceId.cuprum),
      closeTo(before * 0.99, 1e-9),
    );
    sim.replicatorSpeedOf(ResourceId.cuprum).value = 10;
    expect(
      sim.replicatorSeconds(ResourceId.cuprum),
      closeTo(base * math.pow(0.99, 10), 1e-9),
    );
    sim.replicatorSpeedOf(ResourceId.cuprum).value = 100000;
    expect(
      sim.replicatorSeconds(ResourceId.cuprum),
      PrototypeSimulation.replicatorMinSeconds,
    );
  });

  test('an amount level ADDS the tier step to the cycle yield', () {
    final sim = stocked();
    sim.unlockReplicator(ResourceId.cuprum);
    sim.replicatorAmountOf(ResourceId.cuprum).value = 3;
    expect(sim.replicatorYieldOf(ResourceId.cuprum), 100 + 3 * 10);
    final start = cuprum(sim);
    sim.syncReplicator(t0 + (base * second).round());
    expect(cuprum(sim), closeTo(start + 130, 1e-6));
  });

  test('both tracks are bought in the resource itself plus quantonium', () {
    final sim = stocked();
    sim.stock.add(ResourceId.cuprum, BigDouble.fromNum(1e6));
    sim.unlockReplicator(ResourceId.cuprum);
    final quantBefore = sim.stock.amount(ResourceId.quantonium).toDouble();
    expect(
      sim.replicatorSpeedCost(ResourceId.cuprum).toDouble(),
      closeTo(toll * 3, 1e-9),
    );
    expect(
      sim.replicatorAmountCost(ResourceId.cuprum).toDouble(),
      closeTo(toll * 4, 1e-9),
    );
    final quantAsk =
        sim.replicatorSpeedQuant(ResourceId.cuprum).toDouble() +
        sim.replicatorAmountQuant(ResourceId.cuprum).toDouble();
    expect(sim.upgradeReplicatorSpeed(ResourceId.cuprum), isTrue);
    expect(sim.upgradeReplicatorAmount(ResourceId.cuprum), isTrue);
    expect(sim.replicatorSpeedOf(ResourceId.cuprum).value, 1);
    expect(sim.replicatorAmountOf(ResourceId.cuprum).value, 1);
    expect(
      sim.stock.amount(ResourceId.quantonium).toDouble(),
      closeTo(quantBefore - quantAsk, 1e-9),
    );
    // The mineral ask is a tier share of the unlock, doubling per
    // level: cuprum speed base 2500 * 0.1 = 250, level one asks 500.
    expect(
      sim.replicatorSpeedQuant(ResourceId.cuprum).toDouble(),
      closeTo(500, 1e-9),
    );
    expect(
      sim.replicatorAmountQuant(ResourceId.chip).toDouble(),
      closeTo(1500, 1e-9),
    );
    // A locked machine has no tracks to buy.
    expect(sim.upgradeReplicatorSpeed(ResourceId.chip), isFalse);
    expect(sim.upgradeReplicatorAmount(ResourceId.chip), isFalse);
  });

  test('one long span equals the same span in pieces', () {
    final sims = [stocked(), stocked()];
    for (final sim in sims) {
      sim.unlockReplicator(ResourceId.cuprum);
    }
    sims[0].syncReplicator(t0 + 3607 * second);
    for (var t = 7; t <= 3607; t += 60) {
      sims[1].syncReplicator(t0 + t * second);
    }
    sims[1].syncReplicator(t0 + 3607 * second);
    expect(cuprum(sims[0]), closeTo(cuprum(sims[1]), 1e-6));
    expect(
      sims[0].replicatorFractionOf(ResourceId.cuprum).value,
      closeTo(sims[1].replicatorFractionOf(ResourceId.cuprum).value, 1e-6),
    );
  });

  test('a locked machine copies nothing', () {
    final sim = stocked();
    sim.syncReplicator(t0 + 3600 * second);
    expect(cuprum(sim), 10000);
  });

  test('the absence runs the machines at offline efficiency', () {
    final sim = stocked();
    sim.unlockReplicator(ResourceId.cuprum);
    final start = cuprum(sim);
    final gain = sim.settleAbsence(
      nowMs: t0 + 3600 * second,
      seconds: 3600,
      energyPerSecond: 0,
      cycleSeconds: 4,
    );
    // An hour away runs like a quarter-hour online.
    final cycles = (3600 * PrototypeSimulation.offlineEfficiency / base)
        .floor();
    expect(cuprum(sim), closeTo(start + cycles * 100, 1e-6));
    expect(gain.gained[ResourceId.cuprum], isNotNull);
  });

  test('the rate vitrine quotes the payout per second', () {
    final sim = stocked();
    expect(
      sim.replicatorPerSecondOf(ResourceId.cuprum).toDouble(),
      closeTo(100 / base, 1e-9),
    );
    sim.replicatorSpeedOf(ResourceId.cuprum).value = 1;
    expect(
      sim.replicatorPerSecondOf(ResourceId.cuprum).toDouble(),
      closeTo(100 / (base * 0.99), 1e-9),
    );
  });

  test('unlocks, both tracks and the cycle fraction survive a save', () {
    final sim = stocked();
    sim.stock.add(ResourceId.cuprum, BigDouble.fromNum(1e6));
    sim.unlockReplicator(ResourceId.cuprum);
    sim.upgradeReplicatorSpeed(ResourceId.cuprum);
    sim.upgradeReplicatorAmount(ResourceId.cuprum);
    sim.syncReplicator(t0 + (0.4 * base * second).round());

    final back = PrototypeSimulation.rigged()..readJson(sim.toJson());
    expect(back.replicatorUnlockedOf(ResourceId.cuprum).value, isTrue);
    expect(back.replicatorSpeedOf(ResourceId.cuprum).value, 1);
    expect(back.replicatorAmountOf(ResourceId.cuprum).value, 1);
    expect(
      back.replicatorFractionOf(ResourceId.cuprum).value,
      closeTo(sim.replicatorFractionOf(ResourceId.cuprum).value, 1e-9),
    );
    expect(back.replicatorLastSeenMs, sim.replicatorLastSeenMs);
  });
}
