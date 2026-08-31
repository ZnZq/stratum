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

  test('a line converts by wall time: k crafts in exactly k craft-times', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    // 30s base craft, level 0, no speed levels: 3 crafts in 90 seconds --
    // plus whatever the warm-up adds on top.
    sim.syncCraft(t0 + 90 * second);
    final made = cuprum(sim);
    expect(made, greaterThanOrEqualTo(3 * (1 + craftDuplicateChance) - 1e-6));
    // The ramp is capped at +25%, so the span can never pay more than that.
    expect(made, lessThan(3 * 1.25 * (1 + craftDuplicateChance) + 1e-6));
    expect(
      sim.stock.amount(ResourceId.cuprite).toDouble(),
      lessThan(1e7),
      reason: 'inputs were spent',
    );
  });

  test('a fractional span yields fractional output', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + 15 * second);
    expect(cuprum(sim), greaterThan(0));
    expect(cuprum(sim), lessThan(1));
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

  test('the bottleneck input limits conversion and nothing goes negative', () {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1e9));
    sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(12)); // 1.5 crafts
    sim.syncCraft(t0);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + 3600 * second);
    expect(cuprum(sim), closeTo(1.5 * (1 + craftDuplicateChance), 1e-6));
    expect(sim.stock.amount(ResourceId.cuprite).toDouble(), closeTo(0, 1e-6));
    expect(
      sim.stock.amount(ResourceId.regolith).toDouble(),
      greaterThanOrEqualTo(0),
    );
    // Starving reset the warm-up.
    expect(sim.craftLines[0].rampSeconds.value, 0);
  });

  test('compression multiplies yield x2, inputs x3 and time x1.5', () {
    final sim = stocked();
    final line = sim.craftLines[0];
    line.tierCap.value = 4;
    sim.assignCraftRecipe(0, null);
    expect(sim.setCraftTier(0, 4), isTrue);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    expect(
      line.unitsPerCraft.value,
      closeTo(math.pow(2, 4) * (1 + craftDuplicateChance), 1e-9),
    );
    expect(line.craftSeconds.value, closeTo(30 * math.pow(1.5, 4), 1e-9));
    final before = sim.stock.amount(ResourceId.cuprite).toDouble();
    sim.syncCraft(t0 + (30 * math.pow(1.5, 4)).round() * second);
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
    expect(line.craftSeconds.value, closeTo(30 / 1.5, 1e-9));
  });

  test('the warm-up survives a recipe change but not standing idle', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    sim.syncCraft(t0 + 300 * second);
    final ramped = sim.craftLines[0].rampSeconds.value;
    expect(ramped, closeTo(300, 1e-6));
    // Retargeting keeps the bank...
    sim.assignCraftRecipe(0, ResourceId.cuprum, limit: 1000);
    expect(sim.craftLines[0].rampSeconds.value, ramped);
    // ...standing does not.
    sim.assignCraftRecipe(0, null);
    sim.syncCraft(t0 + 360 * second);
    expect(sim.craftLines[0].rampSeconds.value, 0);
  });

  test('a finite order stops at N units and the line reads done', () {
    final sim = stocked();
    sim.assignCraftRecipe(0, ResourceId.cuprum, limit: 2);
    sim.syncCraft(t0 + 3600 * second);
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
    sim.setCraftHalted(0, true);
    // A stopped machine converts nothing and its level is free.
    sim.syncCraft(t0 + 600 * second);
    expect(cuprum(sim), made);
    expect(sim.craftLines[0].rampSeconds.value, 0);
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

  test('the 48h absence cap holds for craft', () {
    final sim = stocked();
    sim.observeWall(t0);
    sim.assignCraftRecipe(0, ResourceId.cuprum);
    const week = 7 * 24 * 3600 * second;
    sim.observeWall(t0 + week);
    sim.syncCraft(t0 + week);
    // 48 hours at 30s/craft with the ramp capped: never a week's worth.
    const twoDaysCrafts = 48 * 3600 / 30.0;
    expect(
      cuprum(sim),
      lessThanOrEqualTo(twoDaysCrafts * 1.25 * (1 + craftDuplicateChance)),
    );
    expect(cuprum(sim), greaterThan(twoDaysCrafts * 0.9));
  });
}
