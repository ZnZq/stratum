import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  const day = Duration.millisecondsPerDay;

  PrototypeSimulation started() {
    final sim = PrototypeSimulation()..cycleStartMs.value = 1;
    return sim;
  }

  test('drift melts the gate by 3% a day', () {
    final sim = started();
    final base = sim.collapseThreshold(1);
    final after = sim.collapseThreshold(1 + day);
    expect((after / base).toDouble(), closeTo(0.97, 1e-9));
  });

  test('drift stops at the cap', () {
    final sim = started();
    final capped = sim.collapseThreshold(
      1 + PrototypeSimulation.collapseDriftCapDays.toInt() * day,
    );
    final muchLater = sim.collapseThreshold(1 + 400 * day);
    expect(muchLater.toDouble(), closeTo(capped.toDouble(), 1e-6));
  });

  test('a full drift window is worth less than one collapse step', () {
    final melt = 1 / (1 - started().driftDiscount(1 + 400 * day));
    expect(melt, lessThan(PrototypeSimulation.collapseThresholdGrowth));
  });

  test('the window reads full only at the cap', () {
    final sim = started();
    expect(sim.driftProgress(1), 0);
    expect(sim.driftProgress(1 + 15 * day), closeTo(0.5, 1e-9));
    expect(sim.driftProgress(1 + 90 * day), 1);
  });
}
