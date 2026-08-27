import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

PrototypeSimulation _funded([double regolith = 1e9]) {
  final sim = PrototypeSimulation(seed: 5150);
  sim.stock.add(ResourceId.regolith, BigDouble.fromNum(regolith));
  return sim;
}

void main() {
  group('the arm levels', () {
    test('every part runs to five hundred and stops', () {
      final sim = _funded(1e300);

      for (final part in ArmPart.values) {
        sim.upgrade(part, levels: 10000);
        expect(sim.levelOf(part).value, PrototypeSimulation.maxPartLevel);
        expect(sim.atMaxLevel(part), isTrue);
        expect(
          sim.canUpgrade(part),
          isFalse,
          reason: 'a part at the cap is not for sale however full the store',
        );
      }
    });

    test('generations are hundreds, and the last one holds the top', () {
      expect(PrototypeSimulation.generationOf(0), 0);
      expect(PrototypeSimulation.generationOf(99), 0);
      expect(PrototypeSimulation.generationOf(100), 1);
      expect(PrototypeSimulation.generationOf(499), 4);
      expect(
        PrototypeSimulation.generationOf(500),
        4,
        reason: 'the five hundredth level is the top of Mk V, not a sixth',
      );
    });

    test('a batch buy stops at what the store can pay for', () {
      // Enough for three levels of the bit and no more: 120 + 134 + 151.
      final sim = _funded(410);

      final bought = sim.upgrade(ArmPart.bit, levels: 10);

      expect(bought, 3);
      expect(sim.bitLevel.value, 3);
      expect(
        sim.stock.amount(ResourceId.regolith).toDouble(),
        lessThan(PrototypeSimulation.costOf(ArmPart.bit, 3).toDouble()),
        reason: 'it stopped because the next level was out of reach',
      );
    });

    test('the affordable count is what a max buy actually lands', () {
      final sim = _funded(50000);
      final predicted = sim.affordableLevels(ArmPart.drive);

      final bought = sim.upgrade(ArmPart.drive, levels: predicted);

      expect(bought, predicted);
      expect(
        sim.canUpgrade(ArmPart.drive),
        isFalse,
        reason: 'a max buy leaves nothing further within reach',
      );
    });
  });

  group('what a part buys', () {
    test('the bit raises the floor of the haul, the drive the ceiling', () {
      final sim = _funded();
      final minBefore = sim.strikeRegolithMin;
      final maxBefore = sim.strikeRegolithMax;

      sim.upgrade(ArmPart.bit, levels: 10);

      expect(
        sim.strikeRegolithMin.toDouble(),
        closeTo(
          minBefore.toDouble() *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03 *
              1.03,
          minBefore.toDouble() * 1e-9,
        ),
      );
      expect(
        '${sim.strikeRegolithMax}',
        '$maxBefore',
        reason: 'the ceiling is the drive\'s, and the drive has not moved',
      );

      final ceilingBefore = sim.strikeRegolithMax;
      sim.upgrade(ArmPart.drive, levels: 4);
      expect(
        sim.strikeRegolithMax.toDouble(),
        closeTo(
          ceilingBefore.toDouble() * 1.05 * 1.05 * 1.05 * 1.05,
          ceilingBefore.toDouble() * 1e-9,
        ),
      );
    });

    test('every haul lands inside the band the parts promise', () {
      final sim = _funded();
      sim.upgrade(ArmPart.bit, levels: 6);
      sim.upgrade(ArmPart.drive, levels: 6);
      // A face too hard to break, so no payout mixes into the roll.
      sim.layerHp.value = BigDouble.fromNum(1e18);
      sim.layerHpMax.value = BigDouble.fromNum(1e18);
      final low = sim.strikeRegolithMin;
      final high =
          sim.strikeRegolithMax *
          BigDouble.fromNum(PrototypeSimulation.strikeCritPower);

      for (var i = 0; i < 200; i++) {
        final before = sim.stock.amount(ResourceId.regolith);
        final outcome = sim.strike();
        if (!outcome.landed) break;
        final gained = sim.stock.amount(ResourceId.regolith) - before;
        expect(gained.gteWithTolerance(low), isTrue);
        expect(high.gteWithTolerance(gained), isTrue);
      }
    });

    test('the drive deepens the bite every blow takes', () {
      final sim = _funded();
      expect(sim.pierceShare, PrototypeSimulation.structuralShare);

      sim.upgrade(ArmPart.drive, levels: 100);

      expect(
        sim.pierceShare,
        closeTo(
          PrototypeSimulation.structuralShare +
              100 * PrototypeSimulation.piercePerLevel,
          1e-12,
        ),
      );
    });

    test('the supply lengthens the burst and shortens the wait', () {
      final sim = _funded(1e300);

      expect(sim.energyCap, 250);
      expect(sim.energySeconds, closeTo(2.0, 1e-12));
      expect(
        sim.energyPerRegen,
        1,
        reason: 'a tick is always one point; the level moves the cadence',
      );

      sim.upgrade(ArmPart.supply, levels: 500);

      expect(sim.energyCap, 250 + 10 * 500);
      expect(
        sim.energySeconds,
        closeTo(2.0 / 1.5, 1e-12),
        reason: 'five hundred levels are +50% rate, so the wait is 1.333 s',
      );
    });
  });

  group('saving the arm', () {
    test('carries the three parts and clamps a doctored level', () {
      final sim = _funded(1e300);
      sim.upgrade(ArmPart.bit, levels: 12);
      sim.upgrade(ArmPart.drive, levels: 3);
      sim.upgrade(ArmPart.supply, levels: 7);

      final restored = PrototypeSimulation()..readJson(sim.toJson());

      expect(restored.bitLevel.value, 12);
      expect(restored.driveLevel.value, 3);
      expect(restored.supplyLevel.value, 7);

      restored.readJson({
        'arm': {'bit': 9000, 'drive': -4, 'supply': 500},
      });
      expect(restored.bitLevel.value, PrototypeSimulation.maxPartLevel);
      expect(restored.driveLevel.value, 0);
      expect(restored.supplyLevel.value, PrototypeSimulation.maxPartLevel);
    });

    test('a save with no arm section reads as a bare arm', () {
      final sim = _funded(1e300)..upgrade(ArmPart.bit, levels: 5);

      sim.readJson(const <String, Object?>{});

      expect(sim.bitLevel.value, 0);
      expect(sim.driveLevel.value, 0);
      expect(sim.supplyLevel.value, 0);
    });
  });
}
