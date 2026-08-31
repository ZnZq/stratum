import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  const second = 1000;
  // Zero epoch is the acknowledged clock's never-observed sentinel, so the
  // bench starts its history at a real instant.
  const t0 = 60 * second;

  PrototypeSimulation stocked() {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1e9));
    sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(1e7));
    sim.stock.add(ResourceId.credits, BigDouble.fromNum(1e9));
    // Stamp the clock so the next sync measures a clean span.
    sim.syncCraft(t0);
    return sim;
  }

  double cuprum(PrototypeSimulation sim) =>
      sim.stock.amount(ResourceId.cuprum).toDouble();

  final base = craftRecipeOf(ResourceId.cuprum)!.baseSeconds;

  test('a line converts by wall time: k crafts in exactly k craft-times', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    // Three base craft-times finish exactly three units (the boost can
    // shave a percent or two, never a whole unit at this length); each
    // unit pays one or, on a duplicate roll, two.
    sim.syncCraft(t0 + (3 * base * second).round());
    final made = cuprum(sim);
    expect(made, greaterThanOrEqualTo(3 - 1e-6));
    expect(made, lessThanOrEqualTo(6 + 1e-6));
    expect(made, equals(made.floorToDouble()), reason: 'whole units only');
    expect(
      sim.stock.amount(ResourceId.cuprite).toDouble(),
      lessThan(1e7),
      reason: 'inputs were spent',
    );
  });

  test('a unit is prepaid on start and delivered whole on finish', () {
    final sim = stocked();
    final cupriteBefore = sim.stock.amount(ResourceId.cuprite).toDouble();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + (base * second) ~/ 2);
    // Half a craft-time in: nothing delivered yet, but the unit's FULL
    // inputs are gone and the fraction shows the work.
    expect(cuprum(sim), 0);
    expect(
      cupriteBefore - sim.stock.amount(ResourceId.cuprite).toDouble(),
      closeTo(8, 1e-6),
    );
    expect(sim.craftLines[0].unitLoaded.value, isTrue);
    expect(sim.craftLines[0].craftProgress, closeTo(0.5, 0.01));
  });

  test('cancelling a job refunds the loaded unit in full', () {
    final sim = stocked();
    final cupriteBefore = sim.stock.amount(ResourceId.cuprite).toDouble();
    final regolithBefore = sim.stock.amount(ResourceId.regolith).toDouble();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + (base * second) ~/ 2);
    sim.assignCraftRecipe(0, null);
    // Everything the unfinished unit took comes back to the shelf.
    expect(
      sim.stock.amount(ResourceId.cuprite).toDouble(),
      closeTo(cupriteBefore, 1e-6),
    );
    expect(
      sim.stock.amount(ResourceId.regolith).toDouble(),
      closeTo(regolithBefore, 1e-6),
    );
    expect(sim.craftLines[0].unitLoaded.value, isFalse);
  });

  test('offline parity: one long span equals the same span in pieces', () {
    final sims = [stocked(), stocked()];
    for (final sim in sims) {
      sim.assignCraftRecipe(0, ResourceId.cuprum);
    }
    sims[0].syncCraft(t0 + 1800 * second);
    for (var t = 60; t <= 1800; t += 60) {
      sims[1].syncCraft(t0 + t * second);
    }
    expect(cuprum(sims[0]), closeTo(cuprum(sims[1]), 1e-6));
  });

  test('a unit that cannot be prepaid never starts', () {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1e9));
    sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(12)); // 1.5 units
    sim.syncCraft(t0);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + 3600 * second);
    // One unit loads (8 cuprite) and finishes; the second needs 8 and
    // finds 4 -- it never starts, nothing is half-taken.
    expect(cuprum(sim), closeTo(1, 1e-6));
    expect(sim.stock.amount(ResourceId.cuprite).toDouble(), closeTo(4, 1e-6));
    expect(sim.craftLines[0].unitLoaded.value, isFalse);
    expect(sim.craftLines[0].starving.value, isTrue);
  });

  test('compression multiplies yield x2, inputs x3 and time x1.5', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.tierCap.value = 4;
    sim.assignCraftRecipe(0, null);
    expect(sim.setCraftTier(0, 4), isTrue);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(line.unitsPerCraft.value, closeTo(math.pow(2, 4), 1e-9));
    expect(line.craftSeconds.value, closeTo(base * math.pow(1.5, 4), 1e-9));
    final before = sim.stock.amount(ResourceId.cuprite).toDouble();
    // A ceil plus one: the rounded span must cover at least one craft.
    sim.syncCraft(t0 + ((base * math.pow(1.5, 4)).ceil() + 1) * second);
    final spent = before - sim.stock.amount(ResourceId.cuprite).toDouble();
    // At least one craft's worth of inputs at x81 moved.
    expect(spent, greaterThanOrEqualTo(8 * math.pow(3, 4) - 1e-6));
  });

  test('a speed level multiplies the pace, never shrinks past zero', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.speedLevel.value = 10;
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(line.speedFactor.value, closeTo(1.5, 1e-9));
    expect(line.craftSeconds.value, closeTo(base / 1.5, 1e-9));
  });

  test('the boost piles up by chance per finished unit and caps', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    // A long run finishes plenty of units: at 25% a pile MUST appear,
    // and it can never pass the cap.
    sim.syncCraft(t0 + 3600 * second);
    expect(line.boostStacks.value, greaterThan(0));
    expect(line.boostStacks.value, lessThanOrEqualTo(craftBoostCap));
    expect(
      line.speedFactor.value,
      closeTo(1 + craftBoostStep * line.boostStacks.value, 1e-9),
    );
    // The boost belongs to the job: retargeting starts it cold.
    sim.assignCraftRecipe(0, ResourceId.cuprum, limit: 1000);
    expect(line.boostStacks.value, 0);
    expect(line.unitOrdinal.value, 0);
  });

  test('a starving bench slowly loses its boost stacks', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + (200 * base * second).round());
    final line = sim.craftLines[0];
    final piled = line.boostStacks.value;
    expect(piled, greaterThan(0));
    // The shelf empties: the loaded unit finishes, then the famine
    // starts eating the pile -- one stack per decay step, banked across
    // pieces, down to zero and no further.
    final held = sim.stock.amount(ResourceId.cuprite);
    sim.stock.spend(ResourceId.cuprite, held);
    final t1 = t0 + (200 * base * second).round();
    for (var k = 1; k <= 12; k++) {
      sim.syncCraft(t1 + k * 10 * second);
    }
    expect(line.starving.value, isTrue);
    expect(line.boostStacks.value, lessThan(piled));
    sim.syncCraft(t1 + 3600 * second);
    expect(line.boostStacks.value, 0);
  });

  test('a finite order stops at N units and the line reads done', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum, limit: 2);
    sim.syncCraft(t0 + 3600 * second);
    // Ordinals 0 and 1 both hash below neither roll here: exactly two.
    expect(cuprum(sim), closeTo(2, 1e-6));
    expect(sim.craftLines[0].done, isTrue);
    expect(sim.craftLines[0].ratePerSecond.value.isZero, isTrue);
    // A finished machine stands: its level is free to change again.
    expect(sim.setCraftTier(0, 0), isTrue);
  });

  test('the level is locked while running and free while standing', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.tierCap.value = 3;
    expect(sim.setCraftTier(0, 2), isTrue);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(sim.setCraftTier(0, 1), isFalse);
    expect(line.tier.value, 2);
    sim.assignCraftRecipe(0, null);
    expect(sim.setCraftTier(0, 3), isTrue);
  });

  test('purchases: line, cap and speed drain credits geometrically', () {
    final sim = stocked();
    expect(sim.craftLineCost.toDouble(), 2000);
    expect(sim.buyCraftLine(), isTrue);
    expect(sim.craftLines, hasLength(3));
    expect(sim.craftLineCost.toDouble(), closeTo(12000, 1e-9));

    expect(sim.craftCapCost(0).toDouble(), 500);
    expect(sim.buyCraftCap(0), isTrue);
    expect(sim.craftLines[0].tierCap.value, 1);
    expect(sim.craftLines[0].tier.value, 0, reason: 'the cap never moves it');
    expect(sim.craftCapCost(0).toDouble(), closeTo(2000, 1e-9));

    expect(sim.craftSpeedCost(0).toDouble(), 300);
    expect(sim.buyCraftSpeed(0), isTrue);
    expect(sim.craftSpeedCost(0).toDouble(), closeTo(480, 1e-9));
  });

  test('the cap track ends at the ceiling', () {
    final sim = stocked();
    sim.stock.add(ResourceId.credits, BigDouble.fromNum(1e12));
    final line = sim.craftLines[0];
    while (sim.canBuyCraftCap(0)) {
      sim.buyCraftCap(0);
    }
    expect(line.tierCap.value, craftTierCapMax);
  });

  test('crafted goods sell, and the new trade shelves gate the sweep', () {
    final sim = stocked();
    sim.stock.add(ResourceId.cuprum, BigDouble.fromNum(10));
    final paid = sim.sellPosition(ResourceId.cuprum);
    expect(paid.toDouble(), closeTo(10 * 9000, 1e-6));

    sim.stock.add(ResourceId.wire, BigDouble.fromNum(1));
    sim.sellingGroupOf('products').value = false;
    expect(sim.sellsInSweep(ResourceId.wire), isFalse);
    expect(sim.sellsInSweep(ResourceId.regolith), isTrue);
  });

  test('the whole bench survives a save', () {
    final sim = stocked();
    sim.buyCraftLine();
    sim.craftLines[0].tierCap.value = 5;
    sim.setCraftTier(0, 3);
    sim.assignCraftRecipe(0, ResourceId.cuprum, limit: 500);
    sim.craftLines[1].speedLevel.value = 4;
    sim.sellingGroupOf('materials').value = false;
    sim.syncCraft(t0 + 120 * second);

    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.craftLines, hasLength(3));
    expect(back.craftLines[0].recipe.value, ResourceId.cuprum);
    expect(back.craftLines[0].tier.value, 3);
    expect(back.craftLines[0].tierCap.value, 5);
    expect(back.craftLines[0].limit.value, 500);
    expect(
      back.craftLines[0].producedCount.value,
      closeTo(sim.craftLines[0].producedCount.value, 1e-9),
    );
    expect(back.craftLines[1].speedLevel.value, 4);
    expect(
      back.craftLines[0].boostStacks.value,
      sim.craftLines[0].boostStacks.value,
    );
    expect(
      back.craftLines[0].unitOrdinal.value,
      sim.craftLines[0].unitOrdinal.value,
    );
    expect(
      back.craftLines[0].unitLoaded.value,
      sim.craftLines[0].unitLoaded.value,
    );
    expect(back.craftLastSeenMs, sim.craftLastSeenMs);
    expect(back.sellingGroupOf('materials').value, isFalse);
    expect(back.sellingGroupOf('resources').value, isTrue);
  });

  test('a save from before craft loads to the default bench', () {
    final sim = stocked();
    final json = sim.toJson();
    json.remove('craft');
    final back = PrototypeSimulation()..readJson(json);
    expect(back.craftLines, hasLength(craftStartLines));
    expect(back.craftLines[0].recipe.value, isNull);
    expect(back.craftLastSeenMs, -1);
  });

  test('an unknown saved recipe melts to an empty line', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    final json = sim.toJson();
    final craft = Map<String, Object?>.from(json['craft'] as Map);
    final lines = List<Object?>.from(craft['lines'] as List);
    lines[0] = {'r': 'unobtainium', 't': 9, 'c': 2};
    craft['lines'] = lines;
    json['craft'] = craft;
    final back = PrototypeSimulation()..readJson(json);
    expect(back.craftLines[0].recipe.value, isNull);
    expect(
      back.craftLines[0].tier.value,
      lessThanOrEqualTo(back.craftLines[0].tierCap.value),
    );
  });

  test('a hand stop halts conversion, frees the level and resumes', () {
    final sim = stocked();
    sim.craftLines[0].tierCap.value = 3;
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + 60 * second);
    final made = cuprum(sim);
    expect(made, greaterThan(0));
    final boostBefore = sim.craftLines[0].boostStacks.value;
    final phaseBefore = sim.craftLines[0].craftProgress;
    sim.setCraftHalted(0, true);
    // A stopped machine is a freeze-frame: nothing converts and nothing
    // drains -- the boost, the loaded unit and its progress hold still.
    sim.syncCraft(t0 + 600 * second);
    expect(cuprum(sim), made);
    expect(sim.craftLines[0].boostStacks.value, boostBefore);
    expect(sim.craftLines[0].craftProgress, phaseBefore);
    expect(sim.setCraftTier(0, 2), isTrue);
    sim.setCraftHalted(0, false);
    sim.syncCraft(t0 + 660 * second);
    expect(cuprum(sim), greaterThan(made));
  });

  test('assigning may set the level with the order', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.tierCap.value = 5;
    sim.assignCraftRecipe(0, ResourceId.cuprum, tier: 3);
    expect(line.tier.value, 3);
    // Clamped to the ceiling, and the mid-job lock still holds afterwards.
    sim.assignCraftRecipe(0, ResourceId.cuprum, tier: 9);
    expect(line.tier.value, 5);
    expect(sim.setCraftTier(0, 1), isFalse);
  });

  test('changing the recipe or the level restarts the current unit', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.tierCap.value = 3;
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + (base * second) ~/ 2);
    expect(line.craftProgress, greaterThan(0));
    // Retargeting starts the unit over...
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(line.craftProgress, 0);
    sim.syncCraft(t0 + (base * second).round());
    expect(line.craftProgress, greaterThan(0));
    // ...and so does a compression change on a standing line -- with the
    // loaded unit refunded at the tier it was paid at.
    final cupriteBefore = sim.stock.amount(ResourceId.cuprite).toDouble();
    sim.setCraftHalted(0, true);
    expect(sim.setCraftTier(0, 2), isTrue);
    expect(line.craftProgress, 0);
    expect(
      sim.stock.amount(ResourceId.cuprite).toDouble(),
      closeTo(cupriteBefore + 8, 1e-6),
      reason: 'the frozen unit was loaded at tier 0 and comes back',
    );
  });

  test('a craft never runs faster than the one-second floor', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.speedLevel.value = 2000; // x101 -- far past the floor
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(line.craftSeconds.value, craftMinSeconds);
    sim.syncCraft(t0 + 10 * second);
    // Ten seconds finish at most ten units, boost or not; duplicates can
    // at worst double each of them.
    expect(cuprum(sim), lessThanOrEqualTo(20 + 1e-6));
    expect(cuprum(sim), greaterThanOrEqualTo(10 - 1e-6));
  });

  test('offline, a line keeps feeding the line that eats its output', () {
    final sim = stocked();
    sim.stock.add(ResourceId.ferrum, BigDouble.fromNum(1e6));
    // The CONSUMER sits at a lower index than its supplier: unsliced,
    // it would starve through the whole absence; sliced, it eats what
    // line 1 delivers minute by minute.
    sim.assignCraftRecipe(0, ResourceId.wire);
    sim.assignCraftRecipe(1, ResourceId.cuprum);
    expect(sim.stock.amount(ResourceId.cuprum).isZero, isTrue);
    final gain = sim.settleAbsence(
      nowMs: t0 + 2700 * second,
      seconds: 2700,
      energyPerSecond: 0,
      cycleSeconds: 4,
    );
    // 45 minutes at the 25% offline pace is ~11 minutes of line time:
    // a handful of wire, but strictly more than the zero the unsliced
    // settlement would have paid.
    expect(sim.stock.amount(ResourceId.wire).toDouble(), greaterThan(2));
    expect(gain.gained[ResourceId.wire], isNotNull);
  });

  test('an absence rolls no duplicates and grows no boost', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.settleAbsence(
      nowMs: t0 + 3600 * second,
      seconds: 3600,
      energyPerSecond: 0,
      cycleSeconds: 4,
    );
    final line = sim.craftLines[0];
    expect(line.unitOrdinal.value, greaterThan(50));
    expect(line.boostStacks.value, 0);
    // No duplicate ever paid: the delivered total is exactly the unit
    // count times the yield, to the last crumb.
    expect(
      line.producedCount.value,
      closeTo(line.unitOrdinal.value * line.unitsPerCraft.value, 1e-6),
    );
  });

  test('the 48h absence cap holds for craft', () {
    final sim = stocked();
    sim.observeWall(t0);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    const week = 7 * 24 * 3600 * second;
    sim.observeWall(t0 + week);
    sim.syncCraft(t0 + week);
    // 48 hours at the base cadence with the boost capped at +15% and
    // every unit doubling at worst: never a week's worth.
    final twoDaysCrafts = 48 * 3600 / base;
    expect(
      cuprum(sim),
      lessThanOrEqualTo(twoDaysCrafts * (1 + craftBoostStep * craftBoostCap) * 2),
    );
    expect(cuprum(sim), greaterThan(twoDaysCrafts * 0.9));
  });
}
