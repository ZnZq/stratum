import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  const day = Duration.millisecondsPerDay;

  /// A run whose cycle started at acknowledged zero, clock armed at t=1.
  PrototypeSimulation started() {
    final sim = PrototypeSimulation.rigged()..observeWall(1);
    sim.cycleStartMs.value = 0;
    return sim;
  }

  /// Walks the wall clock to [toMs] in daily observations, the way a played
  /// game would: no single gap crosses the absence cap.
  void play(PrototypeSimulation sim, int toMs) {
    for (var t = sim.lastWallMs + day; t < toMs; t += day) {
      sim.observeWall(t);
    }
    sim.observeWall(toMs);
  }

  test('drift melts the gate by 3% a day', () {
    final sim = started();
    final base = sim.collapseThreshold(1);
    final after = sim.collapseThreshold(1 + day);
    expect((after / base).toDouble(), closeTo(0.97, 1e-9));
  });

  test('drift stops at the cap when the days are actually lived', () {
    final sim = started();
    play(sim, 1 + 30 * day);
    final capped = sim.collapseThreshold(sim.lastWallMs);
    play(sim, 1 + 60 * day);
    final later = sim.collapseThreshold(sim.lastWallMs);
    expect(later.toDouble(), closeTo(capped.toDouble(), 1e-6));
    expect(
      sim.driftDays(sim.lastWallMs),
      PrototypeSimulation.collapseDriftCapDays,
    );
  });

  test('a full drift window is worth less than one collapse step', () {
    final sim = started();
    play(sim, 1 + 60 * day);
    final melt = 1 / (1 - sim.driftDiscount(sim.lastWallMs));
    expect(melt, lessThan(PrototypeSimulation.collapseThresholdGrowth));
  });

  test('one absence credits at most the absence cap', () {
    final sim = started();
    // Away for a week in one gap: the game acknowledges two days.
    expect(sim.driftDays(1 + 7 * day), closeTo(2.0, 1e-9));
    // And the clamp is per gap, not once ever: bank it, leave again.
    sim.observeWall(1 + 7 * day);
    expect(sim.driftDays(1 + 14 * day), closeTo(4.0, 1e-9));
  });

  test('a clock wound backwards contributes nothing and moves nothing', () {
    final sim = started();
    sim.observeWall(1 + day);
    expect(sim.driftDays(1), closeTo(1.0, 1e-9));
    // The last-observed stamp is the breach detector's evidence: a rewound
    // clock must not be able to overwrite it.
    sim.observeWall(1);
    expect(sim.lastWallMs, 1 + day);
  });

  test('the acknowledged clock survives a save', () {
    final sim = started();
    play(sim, 1 + 3 * day);
    final json = sim.toJson();
    final back = PrototypeSimulation.rigged()..readJson(json);
    expect(back.wallSeenMs, sim.wallSeenMs);
    expect(back.cycleStartMs.value, 0);
    // The absence between the save and the load is one gap: a week later
    // the restored run has banked three lived days plus two capped ones.
    expect(back.driftDays(sim.lastWallMs + 7 * day), closeTo(5.0, 1e-9));
  });
}
