import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// The server wall measures the model in bytes: parameters times the
/// training footprint, against a first server of one gibibyte.
void main() {
  const gib = 1 << 30;

  /// A run holding exactly [parameters] worth of dataset, cycle unstamped
  /// so no fragmentation applies.
  PrototypeSimulation holding(double parameters) {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(
      ResourceId.rawData,
      BigDouble.fromNum(
        parameters * PrototypeSimulation.rawPerCube / sim.compileRate,
      ),
    );
    return sim;
  }

  test('the model takes sixteen bytes a parameter while it trains', () {
    final sim = holding(1000);
    expect(sim.walletEarned.toDouble(), closeTo(1000, 1e-9));
    expect(sim.bytesPerParameter.value, 16);
    expect(sim.modelMemory.toDouble(), closeTo(16000, 1e-6));
  });

  test('the first server holds one gibibyte', () {
    final sim = PrototypeSimulation.rigged();
    expect(sim.collapseThreshold(1).toDouble(), gib.toDouble());
    expect(sim.collapseCost(0, 1).toDouble(), gib.toDouble());
  });

  test('a gibibyte of model fills the first server exactly', () {
    final sim = holding(gib / 16);
    expect(sim.rackFill(0, 1), closeTo(1, 1e-9));
    expect(sim.pendingCollapses(1), 1);
  });

  test('fewer bytes a parameter push the overload away', () {
    final sim = holding(gib / 16);
    sim.bytesPerParameter.value = 8;
    expect(sim.rackFill(0, 1), closeTo(0.5, 1e-9));
    expect(sim.pendingCollapses(1), 0);
  });

  test('the second server continues from where the first ends', () {
    final sim = holding(gib / 16 * 2);
    sim.servers.value = 2;
    expect(sim.rackFill(0, 1), 1);
    final span = PrototypeSimulation.collapseRackGrowth - 1;
    expect(sim.rackFill(1, 1), closeTo(1 / span, 1e-9));
  });
}
