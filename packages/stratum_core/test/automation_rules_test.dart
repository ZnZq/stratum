import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// The five automations: each obeys its settings, runs only once bought,
/// and keeps its settings through a save.
void main() {
  const second = 1000;
  const t0 = 90 * second;

  PrototypeSimulation rich() {
    final sim = PrototypeSimulation.rigged();
    sim.stock.add(ResourceId.credits, BigDouble.fromNum(1e9));
    sim.syncAutomations(t0);
    return sim;
  }

  group('auto-hands', () {
    test('strikes fall due by interval, banked and capped', () {
      final auto = AutoStrike()..intervalSeconds.value = 2;
      expect(auto.due(5), 2);
      expect(auto.due(1), 1);
      expect(auto.due(0.5), 0);
      expect(auto.due(1000), AutoStrike.maxBurst);
      auto.enabled.value = false;
      expect(auto.due(10), 0);
    });

    test('slow the gauge only while bought and switched on', () {
      final sim = rich();
      final rest = sim.energySeconds;
      sim.unlockAutomation(AutomationId.autoHands);
      sim.autoStrike.intervalSeconds.value = 1;
      expect(sim.energySeconds, closeTo(rest * 3, 1e-9));
      sim.autoStrike.enabled.value = false;
      expect(sim.energySeconds, closeTo(rest, 1e-9));
    });

    test('the sync owes the app its strikes once the rung is bought', () {
      final sim = rich();
      expect(sim.syncAutomations(t0 + 10 * second), 0);
      sim.unlockAutomation(AutomationId.autoHands);
      sim.autoStrike.intervalSeconds.value = 2;
      expect(sim.syncAutomations(t0 + 20 * second), 5);
    });
  });

  group('auto-sell', () {
    test('a position sells its share on its interval, above its floor', () {
      final sim = rich();
      sim.unlockAutomation(AutomationId.autoSell);
      sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(1000));
      final rule = sim.autoSeller.ruleOf(ResourceId.cuprite)
        ..enabled.value = true
        ..intervalSeconds.value = 10;
      sim.sellShareOf(ResourceId.cuprite).value = 50;
      sim.syncAutomations(t0 + 5 * second);
      expect(sim.stock.amount(ResourceId.cuprite).toDouble(), 1000);
      sim.syncAutomations(t0 + 10 * second);
      expect(
        sim.stock.amount(ResourceId.cuprite).toDouble(),
        closeTo(500, 1e-9),
      );
      // Under the floor, nothing moves.
      rule.keep.value = BigDouble.fromNum(600);
      sim.syncAutomations(t0 + 20 * second);
      expect(
        sim.stock.amount(ResourceId.cuprite).toDouble(),
        closeTo(500, 1e-9),
      );
    });
  });

  group('auto-requests', () {
    test('respects the protected list and the share cap', () {
      final sim = rich();
      sim.unlockAutomation(AutomationId.autoRequests);
      final auto = sim.autoFulfil;
      final request = TradeRequest(
        needs: [(id: ResourceId.cuprite, amount: BigDouble.fromNum(40))],
        premium: 0.2,
        expiresAtMs: t0 + 600 * second,
      );
      sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(100));
      // 40 of 100 is under the default half: accepted.
      expect(auto.accepts(request), isTrue);
      auto.maxShare.value = 0.25;
      expect(auto.accepts(request), isFalse);
      auto.maxShare.value = 1;
      auto.setBlocked(ResourceId.cuprite, true);
      expect(auto.accepts(request), isFalse);
      auto.setBlocked(ResourceId.cuprite, false);
      sim.requests.add(request);
      final credits = sim.stock.amount(ResourceId.credits);
      sim.syncAutomations(t0 + 1 * second);
      expect(sim.requests, isEmpty);
      expect(sim.stock.amount(ResourceId.credits) > credits, isTrue);
    });
  });

  group('auto-buy', () {
    test('buys the chosen tracks, so many per cycle, in turn', () {
      final sim = rich();
      sim.unlockAutomation(AutomationId.autoBuy);
      final auto = sim.autoBuyer
        ..intervalSeconds.value = 30
        ..perCycle.value = 3;
      auto.setChosen(PrototypeSimulation.autoBuyArmKey(ArmPart.bit), true);
      auto.setChosen(PrototypeSimulation.autoBuyArmKey(ArmPart.drive), true);
      sim.syncAutomations(t0 + 10 * second);
      expect(sim.bitLevel.value, 0);
      sim.syncAutomations(t0 + 30 * second);
      // Three levels across two tracks: bit, drive, bit.
      expect(sim.bitLevel.value, 2);
      expect(sim.driveLevel.value, 1);
    });

    test('a chosen track that cannot be bought is skipped', () {
      final sim = PrototypeSimulation.rigged();
      sim.stock.add(ResourceId.credits, BigDouble.fromNum(2000));
      sim.syncAutomations(t0);
      sim.unlockAutomation(AutomationId.autoBuy);
      sim.autoBuyer.setChosen(
        PrototypeSimulation.autoBuyDrillKey(DrillId.cuprite, DrillPart.radius),
        true,
      );
      sim.autoBuyer.setChosen(
        PrototypeSimulation.autoBuyArmKey(ArmPart.supply),
        true,
      );
      sim.syncAutomations(t0 + 30 * second);
      expect(sim.supplyLevel.value, 1);
      expect(sim.drill(DrillId.cuprite).radius.value, 0);
    });
  });

  group('auto-craft', () {
    test('an idle line takes the most valuable job it can feed', () {
      final sim = rich();
      sim.unlockAutomation(AutomationId.autoCraft);
      sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(1e6));
      sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1e9));
      sim.syncAutomations(t0 + 1 * second);
      final line = sim.craftLines[0];
      expect(line.recipe.value, ResourceId.cuprum);
      expect(sim.autoCrafter.manages(0), isTrue);
      // A busy line is left alone on the next pass.
      final tier = line.tier.value;
      sim.syncAutomations(t0 + 2 * second);
      expect(line.tier.value, tier);
    });

    test('with nothing to feed, lines stay idle', () {
      final sim = rich();
      sim.unlockAutomation(AutomationId.autoCraft);
      sim.syncAutomations(t0 + 1 * second);
      expect(sim.craftLines[0].recipe.value, isNull);
    });
  });

  test('settings survive a save, defaults write nothing', () {
    final sim = rich();
    expect((sim.toJson()['automation'] as Map).containsKey('strike'), isFalse);
    sim.autoStrike.intervalSeconds.value = 4;
    sim.autoStrike.enabled.value = false;
    sim.autoSeller.ruleOf(ResourceId.ferrite)
      ..enabled.value = true
      ..keep.value = BigDouble.fromNum(250);
    sim.autoFulfil.setBlocked(ResourceId.chip, true);
    sim.autoBuyer.perCycle.value = 5;
    sim.autoBuyer.setChosen('arm.bit', true);
    sim.autoCrafter.enabled.value = false;
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.autoStrike.intervalSeconds.value, 4);
    expect(back.autoStrike.enabled.value, isFalse);
    expect(back.autoSeller.ruleOf(ResourceId.ferrite).enabled.value, isTrue);
    expect(
      back.autoSeller.ruleOf(ResourceId.ferrite).keep.value.toDouble(),
      250,
    );
    expect(back.autoFulfil.isBlocked(ResourceId.chip), isTrue);
    expect(back.autoBuyer.perCycle.value, 5);
    expect(back.autoBuyer.isChosen('arm.bit'), isTrue);
    expect(back.autoCrafter.enabled.value, isFalse);
  });

  test('an absence restamps the automations instead of replaying them', () {
    final sim = rich();
    sim.unlockAutomation(AutomationId.autoHands);
    sim.settleAbsence(
      nowMs: t0 + 3600 * second,
      seconds: 3600,
      energyPerSecond: 0,
      cycleSeconds: 4,
    );
    expect(sim.syncAutomations(t0 + 3600 * second + 100), 0);
  });
}
