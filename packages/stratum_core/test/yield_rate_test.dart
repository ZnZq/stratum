import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Moves the face to [depth] and re-derives its density, the way a save load
/// does: setting the depth alone would leave the old layer standing.
PrototypeSimulation _at(int depth, {int seed = 808}) {
  final sim = PrototypeSimulation(seed: seed)..layer.value = depth;
  sim.layerHpMax.value = PrototypeSimulation.densityAt(depth);
  sim.layerHp.value = PrototypeSimulation.densityAt(depth);
  return sim;
}

void main() {
  group('expected yield of one strike', () {
    test('is the drop times how often the lane pays', () {
      final sim = _at(120);

      expect(
        sim.expectedPerStrike(ResourceId.regolith).toDouble(),
        closeTo(
          (sim.strikeRegolithMin + sim.strikeRegolithMax).toDouble() / 2,
          1e-6,
        ),
        reason: 'regolith always pays, so its expectation is the band mean',
      );
      expect(
        sim.expectedPerStrike(ResourceId.cuprite).toDouble(),
        closeTo(PrototypeSimulation.oreDropAt(120).toDouble() * 0.22, 1e-9),
      );
      expect(
        sim.expectedPerStrike(ResourceId.quantonium).toDouble(),
        closeTo(
          PrototypeSimulation.quantoniumDropAt(120) *
              PrototypeSimulation.strikeQuantoniumChance,
          1e-9,
        ),
      );
    });

    test('a lane the depth has not opened is worth nothing', () {
      final sim = _at(10);

      expect(sim.expectedPerStrike(ResourceId.ferrite).isZero, isTrue);
      expect(sim.expectedPerStrike(ResourceId.silicite).isZero, isTrue);
      expect(
        _at(120).expectedPerStrike(ResourceId.ferrite).isZero,
        isFalse,
        reason: 'past its stratum the lane pays like any other',
      );
    });

    test('resources that arrive on events have no strike yield', () {
      final sim = _at(120);

      expect(sim.expectedPerStrike(ResourceId.samples).isZero, isTrue);
      expect(sim.expectedPerStrike(ResourceId.credits).isZero, isTrue);
      expect(sim.expectedPerStrike(ResourceId.compute).isZero, isTrue);
    });
  });

  group('yield per second', () {
    test('counts the hand at its energy rate and the rig at its cycle', () {
      final sim = _at(200);
      final perStrike = sim.expectedPerStrike(ResourceId.regolith).toDouble();

      final rate = sim.yieldPerSecond(
        ResourceId.regolith,
        energyPerSecond: 10,
        cycleSeconds: 4,
      );

      // Ten energy a second buys ten strikes; the rig throws one more every
      // four seconds. The drill's own extraction is nil, so the whole of its
      // income is that strike.
      expect(
        rate.toDouble(),
        closeTo(perStrike * 10 + perStrike / 4, perStrike * 1e-9),
      );
    });

    test('a still hand leaves the rig rate alone', () {
      final sim = _at(200);
      final perStrike = sim.expectedPerStrike(ResourceId.crystals).toDouble();

      final rate = sim.yieldPerSecond(
        ResourceId.crystals,
        energyPerSecond: 0,
        cycleSeconds: 4,
      );

      expect(rate.toDouble(), closeTo(perStrike / 4, perStrike * 1e-9));
    });

    test('a stopped rig leaves the hand rate alone', () {
      final sim = _at(200);
      final perStrike = sim.expectedPerStrike(ResourceId.regolith).toDouble();

      final rate = sim.yieldPerSecond(
        ResourceId.regolith,
        energyPerSecond: 2,
        cycleSeconds: 0,
      );

      expect(rate.toDouble(), closeTo(perStrike * 2, perStrike * 1e-9));
    });

    test('matches what the face actually pays over a long run', () {
      // The rig alone, so the measurement has no hand in it, and a window
      // short enough that the depth barely moves under the sample.
      final sim = _at(362);
      final predicted = sim
          .yieldPerSecond(
            ResourceId.regolith,
            energyPerSecond: 0,
            cycleSeconds: 4,
          )
          .toDouble();

      final before = sim.stock.amount(ResourceId.regolith);
      const cycles = 4000;
      for (var i = 0; i < cycles; i++) {
        sim.tick();
      }
      final measured =
          (sim.stock.amount(ResourceId.regolith) - before).toDouble() /
          (cycles * 4);

      expect(
        measured,
        closeTo(predicted, predicted * 0.05),
        reason:
            'the quoted floor must be what the face really pays, give or '
            'take the bonuses left out of it on purpose',
      );
      expect(
        measured,
        greaterThan(predicted),
        reason: 'crits, echoes and breaks are bonuses, so reality runs above',
      );
    });
  });
}
