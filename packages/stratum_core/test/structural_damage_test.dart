import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  group('structural damage', () {
    test('a blow collapses a share of the structure still standing', () {
      final sim = PrototypeSimulation(seed: 3);
      // The share is earned: give the arm the drive levels that buy it.
      sim.driveLevel.value = 20;
      final wall = BigDouble.fromNum(1e18);
      sim.layerHp.value = wall;
      sim.layerHpMax.value = wall;

      sim.strike();

      final collapsed = (wall - sim.layerHp.value).toDouble();
      final share = 1e18 * sim.pierceShare;
      expect(
        collapsed,
        closeTo(share, share * 0.01),
        reason:
            'against a wall the structural share dwarfs the blow itself, '
            'so the bite is the share within a hair',
      );
    });

    test('the drill cycle throws a full strike, damage included', () {
      final sim = PrototypeSimulation(seed: 5);
      sim.driveLevel.value = 20;
      final wall = BigDouble.fromNum(1e18);
      sim.layerHp.value = wall;
      sim.layerHpMax.value = wall;

      final outcome = sim.tick();

      final collapsed = (wall - sim.layerHp.value).toDouble();
      final blow = (sim.power.value + sim.strikePower).toDouble();
      final expected =
          (blow * (outcome.critical ? PrototypeSimulation.strikeCritPower : 1) +
              1e18 * sim.pierceShare) *
          (1 + outcome.echoes);
      expect(
        collapsed,
        closeTo(expected, expected * 0.02),
        reason: 'the cycle lands rig power plus the strike, not rig alone',
      );
    });

    test('hits to break follows the geometric shrink', () {
      final sim = PrototypeSimulation();
      sim.driveLevel.value = 20;
      final overmatch = 1e6;
      final wall = sim.strikePower * BigDouble.fromNum(overmatch);
      sim.layerHp.value = wall;
      sim.layerHpMax.value = wall;

      final r = sim.pierceShare;
      final expected = (math.log(1 + overmatch * r) / -math.log(1 - r)).ceil();
      expect(sim.hitsToBreak.value, expected);
      expect(
        sim.hitsToBreak.value,
        lessThan(overmatch),
        reason: 'the wall is log-finite, not a million plain hits',
      );
    });
  });
}
