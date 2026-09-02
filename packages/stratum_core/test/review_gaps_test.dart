import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

import 'support/sim_fixtures.dart';

/// The scenarios the 2026-09-01 review found unpinned.
void main() {
  test('the drive track ends where the floor is met: no dead levels sold', () {
    final sim = bottomless();
    final cap = PrototypeSimulation.drillDriveCap(DrillId.regolith);
    final bought = sim.upgradeDrill(
      DrillId.regolith,
      DrillPart.drive,
      levels: cap + 50,
    );
    expect(bought, cap);
    expect(sim.drill(DrillId.regolith).drive.value, cap);
    final before = sim.stock.amount(ResourceId.credits);
    expect(sim.upgradeDrill(DrillId.regolith, DrillPart.drive), 0);
    expect(sim.stock.amount(ResourceId.credits), before);
    expect(
      sim.drillInterval(DrillId.regolith),
      closeTo(PrototypeSimulation.drillIntervalFloor, 1e-9),
    );
  });

  test('with no pierce share the wear bar is plainly linear', () {
    final sim = simAtDepth(40);
    expect(sim.pierceShare, 0);
    sim.layerHp.value = sim.layerHpMax.value * BigDouble.fromNum(0.25);
    expect(sim.layerEffort.value, closeTo(0.75, 1e-9));
  });

  test('a request leaves the board exactly when it expires', () {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1000));
    sim.syncRequests(1000);
    expect(sim.requests, isNotEmpty);
    final expires = sim.requests.first.expiresAtMs;
    sim.syncRequests(expires - 1);
    expect(sim.requests.any((r) => r.expiresAtMs == expires), isTrue);
    sim.syncRequests(expires);
    expect(sim.requests.any((r) => r.expiresAtMs == expires), isFalse);
  });

  test('a long absence posts at most a boardful of requests', () {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1000));
    sim.syncRequests(1000);
    sim.syncRequests(1000 + 40 * PrototypeSimulation.requestIntervalMs);
    expect(sim.requests.length, lessThanOrEqualTo(sim.requestSlots));
  });

  test('a replicator fraction outside 0..1 in a save is clamped', () {
    final sim = PrototypeSimulation.rigged();
    final json = sim.toJson();
    json['replicator'] = {
      'u': ['cuprum'],
      'fr.cuprum': 7.5,
      'sp.cuprum': -3,
    };
    final back = PrototypeSimulation.rigged()..readJson(json);
    expect(back.replicatorFractionOf(ResourceId.cuprum).value, 1.0);
    expect(back.replicatorUnlockedOf(ResourceId.cuprum).value, isTrue);
  });

  test('the simulation clock counts capped absences, not calendar time', () {
    final sim = PrototypeSimulation.rigged();
    sim.observeWall(10000);
    sim.runStartSeenMs = sim.wallSeenMs;
    // A week away is acknowledged as two days.
    sim.observeWall(10000 + 7 * 24 * 3600 * 1000);
    expect(sim.simSeconds(sim.lastWallMs), closeTo(48 * 3600, 1e-6));
  });
}
