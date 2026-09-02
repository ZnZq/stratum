import 'package:stratum_core/stratum_core.dart';

/// The ways a test sets a simulation up, in one place.

/// A fresh run with [credits] in the store.
PrototypeSimulation funded([double credits = 1e9]) {
  final sim = PrototypeSimulation(seed: 5150);
  sim.stock.add(ResourceId.credits, BigDouble.fromNum(credits));
  return sim;
}

/// A pocket deep enough for any ladder in the game: past double's range,
/// so it is built from mantissa and exponent directly.
PrototypeSimulation bottomless() {
  final sim = PrototypeSimulation(seed: 5150);
  sim.stock.add(ResourceId.credits, BigDouble(1, 600));
  return sim;
}

/// A run that has ticked [cycles] times from the default seed.
PrototypeSimulation played(int cycles) {
  final sim = PrototypeSimulation();
  for (var i = 0; i < cycles; i++) {
    sim.tick();
  }
  return sim;
}

/// Moves the face to [depth] and re-derives its density, the way a save
/// load does: setting the depth alone would leave the old layer standing.
PrototypeSimulation simAtDepth(int depth, {int seed = 808}) {
  final sim = PrototypeSimulation(seed: seed)..layer.value = depth;
  sim.layerHpMax.value = PrototypeSimulation.densityAt(depth);
  sim.layerHp.value = PrototypeSimulation.densityAt(depth);
  return sim;
}

/// Pins the face so no blow can break through: accrual tests then see the
/// loot lanes alone, with no break bonuses mixed in.
void pinLayer(PrototypeSimulation sim) {
  sim.layerHp.value = BigDouble.fromNum(1e18);
  sim.layerHpMax.value = BigDouble.fromNum(1e18);
}
