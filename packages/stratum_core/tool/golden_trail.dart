import 'dart:convert';

import 'package:stratum_core/stratum_core.dart';

/// Prints the golden trail the decomposition tests pin: a fixed seed, a
/// fixed script of ticks, strikes and purchases, and the state it lands
/// in. Run once BEFORE a refactor, paste into `test/golden_trail_test.dart`,
/// and every step after must reproduce it to the bit.
void main() {
  final sim = goldenTrail();
  print(jsonEncode(goldenSnapshot(sim)));
}

PrototypeSimulation goldenTrail() {
  final sim = PrototypeSimulation.rigged(seed: 424242);
  const second = 1000;
  const t0 = 90 * second;
  sim.observeWall(t0);
  sim.syncCraft(t0);
  sim.syncReplicator(t0);
  sim.syncRequests(t0);
  var now = t0;
  for (var i = 0; i < 2500; i++) {
    sim.tick();
    if (i % 3 == 0) sim.strike();
    if (i % 200 == 0) {
      sim.regenerateEnergy();
      sim.upgrade(ArmPart.bit, levels: 2);
      sim.upgrade(ArmPart.drive);
      sim.upgradeDrill(DrillId.regolith, DrillPart.radius, levels: 1);
      sim.sellAll();
      sim.grantFundLevels(ResourceId.regolith, 1);
    }
    if (i == 400) sim.assignCraftRecipe(0, ResourceId.cuprum);
    if (i % 50 == 0) {
      now += 7 * second;
      sim.syncCraft(now);
      sim.syncReplicator(now);
      sim.syncRequests(now);
    }
  }
  return sim;
}

Map<String, Object?> goldenSnapshot(PrototypeSimulation sim) => {
  'layer': sim.layer.value,
  'layerHp': sim.layerHp.value.toJson(),
  'stock': sim.stock.toJson(),
  'bit': sim.bitLevel.value,
  'drive': sim.driveLevel.value,
  'radius': sim.drill(DrillId.regolith).radius.value,
  'earned': sim.creditsEarned.value.toJson(),
  'rawData': sim.rawData.value.toJson(),
  'cycleData': sim.cycleData.value.toJson(),
  'craftLine0': sim.craftLines[0].toJson(),
  'requests': sim.requests.length,
  'random': sim.random.toJson(),
};
