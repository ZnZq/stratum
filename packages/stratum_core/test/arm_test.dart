import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

PrototypeSimulation _funded([double credits = 1e9]) {
  final sim = PrototypeSimulation(seed: 5150);
  sim.stock.add(ResourceId.credits, BigDouble.fromNum(credits));
  return sim;
}

/// A pocket deep enough for any ladder in the game: past double's
/// range, so it is built from mantissa and exponent directly.
PrototypeSimulation _bottomless() {
  final sim = PrototypeSimulation(seed: 5150);
  sim.stock.add(ResourceId.credits, BigDouble(1, 600));
  return sim;
}

/// Levels a part as far as it will go, rebuilding it whenever it hits a
/// ceiling -- which is the only way to the top now.
void _maxOut(PrototypeSimulation sim, ArmPart part) {
  while (true) {
    sim.upgrade(part, levels: PrototypeSimulation.maxPartLevel);
    if (!sim.canEvolve(part)) break;
    sim.evolve(part);
  }
}

void main() {
  group('the arm levels', () {
    test('every part runs to a thousand and stops', () {
      final sim = _bottomless();

      for (final part in ArmPart.values) {
        _maxOut(sim, part);
        expect(sim.levelOf(part).value, PrototypeSimulation.maxPartLevel);
        expect(sim.markOf(part).value, PrototypeSimulation.lastMark);
        expect(sim.atMaxLevel(part), isTrue);
        expect(
          sim.canUpgrade(part),
          isFalse,
          reason: 'a part at the cap is not for sale however full the store',
        );
      }
    });

    test('marks are obtained at the listed totals', () {
      // Obtained at 0 / 100 / 300 / 600 / 1000: Mk I plays the first
      // hundred, and every next span is a hundred longer.
      expect(PrototypeSimulation.markCeiling(0), 0);
      expect(PrototypeSimulation.markCeiling(1), 100);
      expect(PrototypeSimulation.markCeiling(2), 300);
      expect(PrototypeSimulation.markCeiling(3), 600);
      expect(PrototypeSimulation.markCeiling(4), 1000);
      expect(PrototypeSimulation.generationOf(0), 0);
      expect(PrototypeSimulation.generationOf(99), 0);
      expect(PrototypeSimulation.generationOf(100), 1);
      expect(PrototypeSimulation.generationOf(299), 1);
      expect(PrototypeSimulation.generationOf(300), 2);
      expect(PrototypeSimulation.generationOf(599), 2);
      expect(PrototypeSimulation.generationOf(600), 3);
      expect(PrototypeSimulation.generationOf(999), 3);
      expect(
        PrototypeSimulation.generationOf(1000),
        4,
        reason: 'the summit itself is where Mk V is earned',
      );
    });

    test('levelling stops at the mark ceiling until the part is rebuilt', () {
      final sim = _bottomless();

      // Mk I plays the first hundred; Mk II is obtained at 100.
      final bought = sim.upgrade(ArmPart.bit, levels: 10000);
      expect(bought, 100);
      expect(sim.bitLevel.value, 100);
      expect(
        sim.canUpgrade(ArmPart.bit),
        isFalse,
        reason: 'however full the store, the next span is not for sale',
      );
      expect(sim.canEvolve(ArmPart.bit), isTrue);

      expect(sim.evolve(ArmPart.bit), 1);
      expect(sim.ceilingOf(ArmPart.bit), 300);
      expect(
        sim.canUpgrade(ArmPart.bit),
        isTrue,
        reason: 'rebuilding it is what opens the next span',
      );
    });

    test('a part not at its ceiling cannot be rebuilt', () {
      final sim = _funded(1e300)..upgrade(ArmPart.drive, levels: 99);

      expect(sim.canEvolve(ArmPart.drive), isFalse);
      expect(
        sim.evolve(ArmPart.drive),
        isNull,
        reason: 'one level short is short',
      );
      expect(sim.driveMark.value, 0);
    });

    test('the last mark has nothing left to rebuild into', () {
      final sim = _bottomless();
      _maxOut(sim, ArmPart.supply);

      expect(sim.canEvolve(ArmPart.supply), isFalse);
      expect(sim.evolve(ArmPart.supply), isNull);
    });

    test('a batch buy stops at what the store can pay for', () {
      // Enough for three levels of the bit and no more: 120 + 163 + 220.
      final sim = _funded(505);

      final bought = sim.upgrade(ArmPart.bit, levels: 10);

      expect(bought, 3);
      expect(sim.bitLevel.value, 3);
      expect(
        sim.stock.amount(ResourceId.credits).toDouble(),
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
      // A hundred drive levels at x1.365 growth run past 1e15 credits.
      final sim = _funded(1e20);
      expect(sim.pierceShare, 0);

      sim.upgrade(ArmPart.drive, levels: 100);

      expect(
        sim.pierceShare,
        closeTo(100 * PrototypeSimulation.piercePerLevel, 1e-12),
      );
    });

    test('the supply lengthens the burst and shortens the wait', () {
      final sim = _bottomless();

      expect(sim.energyCap, 250);
      expect(sim.energySeconds, closeTo(2.0, 1e-12));
      expect(
        sim.energyPerRegen,
        1,
        reason: 'a tick is always one point; the level moves the cadence',
      );

      _maxOut(sim, ArmPart.supply);

      expect(sim.energyCap, 250 + 10 * 1000);
      expect(
        sim.energySeconds,
        closeTo(2.0 / 2.0, 1e-12),
        reason: 'a thousand levels are +100% rate, so the wait is 1 s',
      );
    });
  });

  group('what a part remembers', () {
    test('the peak follows the marks built and never comes back down', () {
      final sim = _bottomless();

      sim.upgrade(ArmPart.bit, levels: 100);
      sim.evolve(ArmPart.bit);
      expect(sim.knownGeneration(ArmPart.bit), 1);

      // A restart takes the hardware back; what was learned about it stays.
      sim.bitLevel.value = 0;
      sim.bitMark.value = 0;
      expect(
        sim.knownGeneration(ArmPart.bit),
        1,
        reason: 'a mark once built stays readable after a restart',
      );

      sim.upgrade(ArmPart.bit, levels: 100);
      sim.evolve(ArmPart.bit);
      expect(sim.knownGeneration(ArmPart.bit), 1);
      sim.upgrade(ArmPart.bit, levels: 200);
      sim.evolve(ArmPart.bit);
      expect(sim.knownGeneration(ArmPart.bit), 2);
    });

    test('a save from before the peaks trusts where the part stands', () {
      final sim = PrototypeSimulation()
        ..readJson({
          'arm': {'bit': 240, 'drive': 0, 'supply': 0},
        });

      expect(
        sim.knownGeneration(ArmPart.bit),
        1,
        reason: 'level 240 has earned Mk II (100) but not Mk III (300)',
      );
    });

    test('a mark above its level threshold melts to the walked one', () {
      final sim = PrototypeSimulation()
        ..readJson({
          'arm': {'bit': 300, 'bitMark': 3, 'bitPeak': 0},
        });

      // Level 300 has earned Mk III (mark 2); the doctored Mk IV melts.
      expect(sim.bitMark.value, 2);
      expect(sim.peakOf(ArmPart.bit).value, 2);
    });
  });

  group('saving the arm', () {
    test('carries the three parts and clamps a doctored level', () {
      final sim = _bottomless();
      sim.upgrade(ArmPart.bit, levels: 12);
      sim.upgrade(ArmPart.drive, levels: 3);
      sim.upgrade(ArmPart.supply, levels: 7);

      sim.upgrade(ArmPart.bit, levels: 88);
      sim.evolve(ArmPart.bit);

      final restored = PrototypeSimulation()..readJson(sim.toJson());

      expect(restored.bitMark.value, 1);
      expect(restored.peakOf(ArmPart.bit).value, 1);
      expect(restored.bitLevel.value, 100);
      expect(restored.driveLevel.value, 3);
      expect(restored.supplyLevel.value, 7);

      restored.readJson({
        'arm': {'bit': 9000, 'drive': -4, 'supply': 9000},
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
