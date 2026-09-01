import 'package:stratum_core/stratum_core.dart';

/// Checks an analytic per-second yield against a measured run.
///
/// The readout the UI wants is "what the face pays right now", so the
/// analytic side is evaluated at a fixed depth and the measurement is taken
/// over a window short enough that the depth barely moves.
void main() {
  const tickSeconds = 4.0;
  // A short window where the face falls fast, a long one where it does not:
  // the analytic figure is instantaneous, so a window that sinks tens of
  // metres would be compared against a depth that no longer exists.
  for (final (depth, sampleCycles) in [(0, 12), (120, 200), (362, 4000)]) {
    final sim = PrototypeSimulation(seed: 4242)..layer.value = depth;
    sim.drills.value = 7;
    sim.drillPowerLevel.value = 6;
    // Moving the depth by hand leaves the face as it was, so the density has
    // to be re-derived -- otherwise the analytic side reads a stale layer.
    sim.layerHpMax.value = PrototypeSimulation.densityAt(depth);
    sim.layerHp.value = PrototypeSimulation.densityAt(depth);

    // The echo chain means a tick is worth slightly more than one cycle.
    var echoFactor = 0.0;
    for (var k = 0; k <= 6; k++) {
      echoFactor += _pow(sim.echoChance, k);
    }
    final strikesPerSecond = echoFactor / tickSeconds;

    // A crit multiplies the haul, so it lifts the average by its own odds.
    final critFactor =
        1 +
        PrototypeSimulation.strikeCritChance *
            (PrototypeSimulation.strikeCritPower - 1);

    final mean = (sim.strikeRegolithMin + sim.strikeRegolithMax).toDouble() / 2;
    final perStrike = <ResourceId, double>{
      ResourceId.regolith: mean * critFactor,
      ResourceId.crystals:
          sim.crystalChance *
          PrototypeSimulation.crystalDropAt(depth).toDouble() *
          critFactor,
      ResourceId.quantonium:
          PrototypeSimulation.strikeQuantoniumChance *
          PrototypeSimulation.quantoniumDropAt(depth) *
          critFactor,
      for (final row in PrototypeSimulation.oreTable)
        if (depth >= row.unlockAt)
          row.id:
              row.chance *
              PrototypeSimulation.oreDropAt(depth).toDouble() *
              critFactor,
    };

    // Breaking the face pays on top, so the rate has to amortise it: how
    // much of a layer one blow takes down, times what a layer pays.
    final blow =
        (sim.power.value + sim.strikePower).toDouble() * critFactor +
        sim.layerHpMax.value.toDouble() * sim.pierceShare;
    var layersPerStrike = blow / sim.layerHpMax.value.toDouble();
    if (layersPerStrike > PrototypeSimulation.maxLayersPerCycle) {
      layersPerStrike = PrototypeSimulation.maxLayersPerCycle.toDouble();
    }
    final thick = PrototypeSimulation.isThick(depth);
    final span = thick ? PrototypeSimulation.thickSpan.toDouble() : 1.5;
    final perBreak = <ResourceId, double>{
      ResourceId.regolith: sim.regolithPerCycle.value.toDouble() * span,
      if (thick) ...{
        ResourceId.crystals:
            PrototypeSimulation.crystalDropAt(depth).toDouble() * span,
        ResourceId.quantonium:
            PrototypeSimulation.quantoniumDropAt(depth) * span,
        for (final row in PrototypeSimulation.oreTable)
          if (depth >= row.unlockAt)
            row.id: PrototypeSimulation.oreDropAt(depth).toDouble() * span,
      },
    };

    final before = {
      for (final id in ResourceId.values) id: sim.stock.amount(id).toDouble(),
    };
    for (var i = 0; i < sampleCycles; i++) {
      sim.tick();
    }
    final seconds = sampleCycles * tickSeconds;

    print('--- $depth m (проміряно ${sim.layer.value - depth} м за вибірку)');
    for (final id in [
      ResourceId.regolith,
      ResourceId.cuprite,
      ResourceId.crystals,
      ResourceId.quantonium,
    ]) {
      final analytic =
          (perStrike[id] ?? 0) * strikesPerSecond +
          (perBreak[id] ?? 0) * layersPerStrike * strikesPerSecond;
      final measured =
          (sim.stock.amount(id).toDouble() - before[id]!) / seconds;
      final gap = analytic == 0 ? 0 : (measured - analytic) / analytic * 100;
      print(
        '${id.name.padRight(11)} '
        'аналітика ${analytic.toStringAsExponential(3)}/с  '
        'заміряно ${measured.toStringAsExponential(3)}/с  '
        'розбіжність ${gap.toStringAsFixed(1)}%',
      );
    }
  }
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
