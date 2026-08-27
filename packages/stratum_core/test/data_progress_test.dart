import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Pins the face so no blow can break through: accrual tests then see the
/// loot lanes alone, with no break bonuses mixed in.
void _pinLayer(PrototypeSimulation sim) {
  sim.layerHp.value = BigDouble.fromNum(1e18);
  sim.layerHpMax.value = BigDouble.fromNum(1e18);
}

/// The chance the loot table gives a lane at [layer]; guaranteed lanes are 1.
double _chanceAt(ResourceId id, int layer) => switch (id) {
  ResourceId.cuprite => 0.22,
  ResourceId.ferrite => 0.15,
  ResourceId.silicite => 0.12,
  ResourceId.crystals => PrototypeSimulation.crystalChanceAt(layer),
  ResourceId.quantonium => PrototypeSimulation.strikeQuantoniumChance,
  _ => 1,
};

/// What one sighting of a lane typically yields at [layer] -- the unit a haul
/// is measured in.
double _typicalAt(ResourceId id, int layer, double regolithMean) =>
    switch (id) {
      ResourceId.regolith => regolithMean,
      ResourceId.crystals => PrototypeSimulation.crystalDropAt(
        layer,
      ).toDouble(),
      ResourceId.quantonium => PrototypeSimulation.quantoniumDropAt(
        layer,
      ).toDouble(),
      _ => PrototypeSimulation.oreDropAt(layer).toDouble(),
    };

double _meanOf(PrototypeSimulation sim) =>
    (sim.strikeRegolithMin + sim.strikeRegolithMax).toDouble() / 2;

/// The measurement value of one haul: how many typical drops it is, over how
/// often such a drop is seen.
double _information(
  ResourceId id,
  double amount,
  int layer,
  double regolithMean,
) => amount / _typicalAt(id, layer, regolithMean) / _chanceAt(id, layer);

void main() {
  group('raw data accrual', () {
    test('a strike books measurements, not tonnage', () {
      final sim = PrototypeSimulation(seed: 11);
      _pinLayer(sim);
      final mean = _meanOf(sim);

      final outcome = sim.strike();

      expect(outcome.landed, isTrue);
      var expected = _information(
        ResourceId.regolith,
        outcome.regolithGained.toDouble(),
        0,
        mean,
      );
      outcome.oresGained.forEach((id, amount) {
        expected += _information(id, amount.toDouble(), 0, mean);
      });
      // Depth factor at the surface is one metre, so raw equals the units.
      expect(sim.rawData.value.toDouble(), closeTo(expected, expected * 1e-9));
      expect(sim.cycleData.value.toDouble(), sim.rawData.value.toDouble());
    });

    test('a plain strike is worth a handful of units, never a fortune', () {
      final shallow = PrototypeSimulation(seed: 7);
      _pinLayer(shallow);
      shallow.strike();

      final deep = PrototypeSimulation(seed: 7);
      deep.layer.value = 400;
      _pinLayer(deep);
      deep.strike();

      expect(
        shallow.rawData.value.toDouble(),
        lessThan(10),
        reason: 'one strike is a few sightings, whatever the haul weighs',
      );
      expect(
        deep.rawData.value.toDouble() / 401,
        lessThan(10),
        reason:
            'at depth the tonnage is tens of thousands of times larger, so '
            'only the depth factor may separate the two -- not the amounts',
      );
    });

    test('the drill cycle books through the same formula', () {
      final sim = PrototypeSimulation(seed: 4);
      _pinLayer(sim);
      final mean = _meanOf(sim);
      final before = {
        for (final id in ResourceId.values) id: sim.stock.amount(id),
      };

      sim.tick();

      var expected = 0.0;
      for (final id in ResourceId.values) {
        final delta = (sim.stock.amount(id) - before[id]!).toDouble();
        if (delta <= 0) continue;
        expected += _information(id, delta, 0, mean);
      }
      expect(sim.rawData.value.toDouble(), closeTo(expected, expected * 1e-9));
    });

    test('a thick break books its guaranteed payout as certain sightings', () {
      final sim = PrototypeSimulation(seed: 2);
      sim.layer.value = 24;
      sim.layerHp.value = BigDouble.fromNum(0.5);
      sim.layerHpMax.value = BigDouble.fromNum(0.5);
      final mean = _meanOf(sim);

      final outcome = sim.strike();

      expect(outcome.thickLayersBroken, 1);
      var loot = _information(
        ResourceId.regolith,
        outcome.regolithGained.toDouble(),
        24,
        mean,
      );
      outcome.oresGained.forEach((id, amount) {
        loot += _information(id, amount.toDouble(), 24, mean);
      });
      // Guaranteed, so chance one: three spans of regolith over the strike's
      // own share, plus three of every other open lane.
      const span = PrototypeSimulation.thickSpan;
      final broke = span / PrototypeSimulation.strikeShareOfRig + span * 3;
      final expected = (loot + broke) * 25;
      expect(sim.rawData.value.toDouble(), closeTo(expected, expected * 1e-9));
    });

    test('offline books one unit per open lane per strike', () {
      final sim = PrototypeSimulation();

      sim.claimOffline(seconds: 400, energyPerSecond: 0, cycleSeconds: 4);

      // Regolith, crystals and quantonium are always open; at the surface
      // only cuprite is unlocked among the ores. A still hand leaves the rig
      // at one strike every four seconds, throttled to a quarter.
      final strikes = 400 / 4 * PrototypeSimulation.offlineEfficiency;
      final expected = strikes * 4;
      expect(sim.rawData.value.toDouble(), closeTo(expected, expected * 1e-9));
    });
  });

  group('the wallet function', () {
    test('compresses the cycle gross and banks by difference', () {
      final sim = PrototypeSimulation();
      sim.cycleData.value = BigDouble.fromNum(1e12);

      final earned = math
          .pow(1e12, PrototypeSimulation.dataExponentBase)
          .toDouble();
      expect(sim.walletEarned.toDouble(), closeTo(earned, earned * 1e-9));
      expect(sim.bankableData.value.toDouble(), closeTo(earned, earned * 1e-9));

      sim.dataBanked.value = BigDouble.fromNum(5);
      expect(
        sim.bankableData.value.toDouble(),
        closeTo(earned - 5, earned * 1e-9),
      );

      sim.dataBanked.value = BigDouble.fromNum(1e9);
      expect(
        sim.bankableData.value.isZero,
        isTrue,
        reason: 'already paid out more than the function has earned',
      );
    });

    test('banking in pieces pays exactly what banking once would', () {
      const exponent = PrototypeSimulation.dataExponentBase;
      final once = math.pow(1e9, exponent).toDouble();

      final sim = PrototypeSimulation();
      var banked = 0.0;
      for (final gross in [1e6, 1e7, 5e8, 1e9]) {
        sim.cycleData.value = BigDouble.fromNum(gross);
        banked += sim.bankableData.value.toDouble();
        sim.dataBanked.value = sim.walletEarned;
      }

      expect(
        banked,
        closeTo(once, once * 1e-9),
        reason: 'when a run is restarted cannot change what a cycle earns',
      );
    });

    test('the exponent upgrade is capped hard', () {
      final sim = PrototypeSimulation();
      expect(sim.dataExponent, closeTo(0.25, 1e-12));
      sim.dataExponentLevel.value = 3;
      expect(sim.dataExponent, closeTo(0.28, 1e-12));
      sim.dataExponentLevel.value = 40;
      expect(sim.dataExponent, closeTo(0.35, 1e-12));
    });
  });

  group('the collapse gate', () {
    test('the threshold drifts down with wall-clock days', () {
      final sim = PrototypeSimulation();
      final base = PrototypeSimulation.collapseThresholdBase.toDouble();

      expect(
        sim.collapseThreshold(12345).toDouble(),
        base,
        reason: 'an unstamped cycle does not drift',
      );

      sim.cycleStartMs.value = 1000;
      expect(sim.collapseThreshold(1000).toDouble(), base);
      expect(
        sim.collapseThreshold(500).toDouble(),
        base,
        reason: 'a clock wound backwards counts as no time passed',
      );
      expect(
        sim.collapseThreshold(1000 + Duration.millisecondsPerDay).toDouble(),
        closeTo(base * 0.97, base * 1e-9),
      );
      expect(
        sim
            .collapseThreshold(1000 + 7 * Duration.millisecondsPerDay)
            .toDouble(),
        closeTo(base * math.pow(0.97, 7), base * 1e-9),
      );
    });

    test('a deep run does not oversaturate in a handful of cycles', () {
      final sim = PrototypeSimulation()..layer.value = 400;
      _pinLayer(sim);

      for (var i = 0; i < 200; i++) {
        sim.tick();
      }

      expect(
        sim.collapseReady(0),
        isFalse,
        reason:
            'the collapse is a milestone of days; two hundred cycles at '
            'four hundred metres must not open it',
      );
    });

    test('the gate rises with every collapse already made', () {
      final sim = PrototypeSimulation();
      final base = PrototypeSimulation.collapseThresholdBase.toDouble();
      sim.collapses.value = 3;
      expect(
        sim.collapseThreshold(0).toDouble(),
        closeTo(
          base * math.pow(PrototypeSimulation.collapseThresholdGrowth, 3),
          base * 1e-9,
        ),
      );
    });

    test('readiness compares with tolerance', () {
      final sim = PrototypeSimulation();
      expect(sim.collapseReady(0), isFalse);
      sim.rawData.value = PrototypeSimulation.collapseThresholdBase;
      expect(
        sim.collapseReady(0),
        isTrue,
        reason: 'exactly the threshold must count as reached',
      );
    });
  });

  group('saving the data', () {
    test('survives a round-trip and a dataless save resets it', () {
      final sim = PrototypeSimulation();
      sim.rawData.value = BigDouble.fromNum(123);
      sim.cycleData.value = BigDouble.fromNum(456);
      sim.dataBanked.value = BigDouble.fromNum(7);
      sim.dataWallet.value = BigDouble.fromNum(3);
      sim.dataExponentLevel.value = 2;
      sim.collapses.value = 4;
      sim.cycleStartMs.value = 987654;

      final restored = PrototypeSimulation()..readJson(sim.toJson());

      expect(restored.rawData.value.toDouble(), closeTo(123, 1e-9));
      expect(restored.cycleData.value.toDouble(), closeTo(456, 1e-9));
      expect(restored.dataBanked.value.toDouble(), closeTo(7, 1e-9));
      expect(restored.dataWallet.value.toDouble(), closeTo(3, 1e-9));
      expect(restored.dataExponentLevel.value, 2);
      expect(restored.collapses.value, 4);
      expect(restored.cycleStartMs.value, 987654);

      restored.readJson(<String, Object?>{});
      expect(restored.rawData.value.isZero, isTrue);
      expect(restored.cycleData.value.isZero, isTrue);
      expect(restored.cycleStartMs.value, 0);
    });
  });
}
