import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

import 'support/sim_fixtures.dart';

void main() {
  group('raw data', () {
    test('is dug out of the rock like anything else', () {
      final sim = PrototypeSimulation(seed: 7);
      pinLayer(sim);

      const strikes = 4000;
      for (var i = 0; i < strikes; i++) {
        // Topped up every blow: this measures the lane's odds, not how deep
        // the magazine is.
        sim.energy.value = sim.energyCap;
        sim.strike();
        pinLayer(sim);
      }

      final drop = PrototypeSimulation.rawDataDropAt(sim.layer.value);
      final expected =
          drop.toDouble() * PrototypeSimulation.rawDataChance * strikes;
      final actual = sim.rawData.value.toDouble();

      // Crits lift the haul above the plain expectation, so the measured
      // total sits a little high -- never low, and never by a lot.
      expect(actual, greaterThan(expected * 0.85));
      expect(actual, lessThan(expected * 1.35));
    });

    test('does not inherit the ore curve', () {
      // The regression that cost a live save: drop volumes inflate as 1.03^m,
      // and data that rode that curve made one deep strike worth thousands of
      // shallow ones, so every fixed collapse gate fell in minutes.
      final at0 = PrototypeSimulation.rawDataDropAt(0).toDouble();
      final at200 = PrototypeSimulation.rawDataDropAt(200).toDouble();
      final at400 = PrototypeSimulation.rawDataDropAt(400).toDouble();

      // Equal steps for equal depth: linear, so a deep strike is worth a
      // handful of shallow ones rather than thousands. An exponential lane
      // would put the second step far above the first.
      expect(at400 - at200, closeTo(at200 - at0, 1e-9));
      expect(at400 / at0, lessThan(25));
    });

    test('the cycle books it into the cycle total as well as the store', () {
      final sim = PrototypeSimulation(seed: 3);
      pinLayer(sim);

      for (var i = 0; i < 2000; i++) {
        sim.tick();
        pinLayer(sim);
      }

      expect(sim.rawData.value.toDouble(), greaterThan(0));
      // Everything the store holds this run was produced this cycle, and the
      // cycle total is what the wallet is compressed from.
      expect(
        sim.cycleData.value.toDouble(),
        closeTo(sim.rawData.value.toDouble(), 1e-6),
      );
    });

    test('a thick break pays its substrate outright', () {
      final sim = PrototypeSimulation(seed: 11);
      while (!PrototypeSimulation.isThick(sim.layer.value)) {
        sim.layer.value = sim.layer.value + 1;
      }
      final before = sim.rawData.value;
      final at = sim.layer.value;

      sim.layerHp.value = BigDouble.fromNum(0.0001);
      sim.tick();

      final guaranteed =
          PrototypeSimulation.rawDataDropAt(at).toDouble() *
          PrototypeSimulation.thickSpan;
      // The strike that broke it may have rolled the lane too, so the floor
      // is what matters: the break's own payout is never skipped.
      expect(
        (sim.rawData.value - before).toDouble(),
        greaterThanOrEqualTo(guaranteed - 1e-9),
      );
    });

    test('an absence earns it at the lane expectation', () {
      final sim = PrototypeSimulation(seed: 5);
      final gain = sim.claimOffline(
        seconds: 3600,
        energyPerSecond: 0.5,
        cycleSeconds: 4,
      );

      final booked = gain.gained[ResourceId.rawData]!;
      expect(booked.toDouble(), greaterThan(0));
      // It lands in the store and in the cycle total, not just the store --
      // an absence advances the collapse gate like presence does.
      expect(sim.rawData.value.toDouble(), closeTo(booked.toDouble(), 1e-9));
      expect(sim.cycleData.value.toDouble(), closeTo(booked.toDouble(), 1e-9));
    });

    test('a restart wipes what was dug but not what the cycle produced', () {
      final sim = PrototypeSimulation(seed: 9);
      pinLayer(sim);
      for (var i = 0; i < 1500; i++) {
        sim.strike();
        pinLayer(sim);
      }
      final produced = sim.cycleData.value.toDouble();
      expect(produced, greaterThan(0));

      // A Restart wipes what was mined. Substrate is mined, so it goes with
      // the rest; the record of what the CYCLE produced is not mined and
      // stays, which is what makes banking spam-proof.
      sim.stock.clear(const [ResourceId.rawData]);

      expect(sim.rawData.value.isZero, isTrue);
      expect(sim.cycleData.value.toDouble(), closeTo(produced, 1e-9));
    });
  });
}
