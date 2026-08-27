import 'package:stratum_core/stratum_core.dart';

/// How long one run takes to oversaturate, measured rather than guessed.
///
/// Run with `dart run tool/data_pace.dart` from the package root.
void main() {
  for (final depth in [0, 100, 200, 360, 600, 1000]) {
    final sim = PrototypeSimulation(seed: 99)..layer.value = depth;
    // A face too hard to break, so the sample measures the loot lanes at a
    // fixed depth rather than sliding deeper mid-measurement.
    sim.layerHp.value = BigDouble.fromNum(1e300);
    sim.layerHpMax.value = BigDouble.fromNum(1e300);

    const cycles = 20000;
    for (var i = 0; i < cycles; i++) {
      sim.tick();
    }
    final perCycle = sim.rawData.value.toDouble() / cycles;
    // The heartbeat is four seconds, so a day of pure idling is this many.
    const cyclesPerDay = 86400 / 4;
    final perDay = perCycle * cyclesPerDay;
    final days = PrototypeSimulation.collapseThresholdBase.toDouble() / perDay;
    print(
      '${depth.toString().padLeft(5)} m  '
      'per cycle ${perCycle.toStringAsFixed(1).padLeft(9)}  '
      'per day ${perDay.toStringAsFixed(0).padLeft(11)}  '
      'days to collapse ${days.toStringAsFixed(1)}',
    );
  }
}
