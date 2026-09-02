import 'dart:convert';

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// The automation ladder: a fresh run has none, the drill is bought with
/// credits, and until it is bought the rig neither cycles nor counts.
void main() {
  test('a fresh run has no automation at all', () {
    final sim = PrototypeSimulation();
    for (final id in AutomationId.values) {
      expect(sim.automationUnlockedOf(id).value, isFalse, reason: id.name);
    }
    expect(sim.drillOwned(DrillId.regolith), isFalse);
  });

  test('without the drill a tick does nothing and the rig lane is zero', () {
    final sim = PrototypeSimulation();
    final layer = sim.layer.value;
    final hp = sim.layerHp.value;
    final regolith = sim.regolith.value;
    final outcome = sim.tick();
    expect(identical(outcome, CycleOutcome.none), isTrue);
    expect(sim.layer.value, layer);
    expect(sim.layerHp.value, hp);
    expect(sim.regolith.value, regolith);
    // The yield rate counts the hand alone.
    final hand = sim.yieldPerSecond(
      ResourceId.regolith,
      energyPerSecond: 1,
      cycleSeconds: 0,
    );
    final both = sim.yieldPerSecond(
      ResourceId.regolith,
      energyPerSecond: 1,
      cycleSeconds: 4,
    );
    expect(both.toDouble(), closeTo(hand.toDouble(), 1e-12));
    // And the blow is the arm's own, with no rig to lean on.
    expect(sim.strikePower, sim.armPowerAt(sim.bitLevel.value));
    expect(sim.canUpgradeDrill(DrillId.regolith, DrillPart.radius), isFalse);
  });

  test('the rig is bought with credits, once, on its own', () {
    final sim = PrototypeSimulation();
    expect(sim.canBuyRig, isFalse);
    expect(sim.buyRig(), isFalse);
    sim.stock.add(ResourceId.credits, sim.rigCost);
    expect(sim.canBuyRig, isTrue);
    expect(sim.buyRig(), isTrue);
    expect(sim.stock.amount(ResourceId.credits).isZero, isTrue);
    expect(sim.drillOwned(DrillId.regolith), isTrue);
    expect(sim.buyRig(), isFalse);
    // The rig now cycles.
    final before = sim.regolith.value;
    sim.tick();
    expect(sim.regolith.value > before, isTrue);
  });

  test('every rung after the drill has a credit price and stays shut', () {
    final sim = PrototypeSimulation();
    for (final id in AutomationId.values) {
      expect(Automations.costOf(id), isNotNull, reason: id.name);
      expect(sim.canUnlockAutomation(id), isFalse, reason: id.name);
    }
    sim.stock.add(ResourceId.credits, BigDouble.fromNum(1e9));
    for (final id in AutomationId.values) {
      expect(sim.unlockAutomation(id), isTrue, reason: id.name);
    }
    expect(sim.unlockAutomation(AutomationId.autoCraft), isFalse);
  });

  test('unlocks survive a save, and a fresh save writes none', () {
    final sim = PrototypeSimulation();
    expect(sim.toJson()['automation'], isEmpty);
    sim.stock.add(ResourceId.credits, BigDouble.fromNum(1e6));
    sim.buyRig();
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.drillOwned(DrillId.regolith), isTrue);
    expect(back.automationUnlockedOf(AutomationId.autoHands).value, isFalse);
  });

  test('a save from before the ladder keeps the rig it always had', () {
    final codec = SaveCodec(
      currentVersion: stratumSaveVersion,
      migrations: stratumSaveMigrations,
    );
    final out = codec.decode(
      jsonEncode({
        'version': 8,
        'sections': {
          'run': {'layer': 3},
        },
      }),
    );
    final run = Map<String, Object?>.from(out.sections['run'] as Map);
    final sim = PrototypeSimulation()..readJson(run);
    expect(sim.drillOwned(DrillId.regolith), isTrue);
  });

  test('a v9 save moves the rig off the ladder and keeps the rest', () {
    final codec = SaveCodec(
      currentVersion: stratumSaveVersion,
      migrations: stratumSaveMigrations,
    );
    final out = codec.decode(
      jsonEncode({
        'version': 9,
        'sections': {
          'run': {
            'automation': {
              'u': ['drill', 'autoSell'],
            },
          },
        },
      }),
    );
    final run = Map<String, Object?>.from(out.sections['run'] as Map);
    final sim = PrototypeSimulation()..readJson(run);
    expect(sim.drillOwned(DrillId.regolith), isTrue);
    expect(sim.automationUnlockedOf(AutomationId.autoSell).value, isTrue);
    expect((run['automation'] as Map)['u'], ['autoSell']);
  });

  test('a rigged bench simulation starts with the drill for free', () {
    final sim = PrototypeSimulation.rigged();
    expect(sim.drillOwned(DrillId.regolith), isTrue);
    expect(sim.stock.amount(ResourceId.credits).isZero, isTrue);
  });
}
