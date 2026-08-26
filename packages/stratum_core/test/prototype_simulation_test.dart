import 'dart:convert';

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

String _json(Object? value) => jsonEncode(value);

PrototypeSimulation _played(int cycles) {
  final sim = PrototypeSimulation();
  for (var i = 0; i < cycles; i++) {
    sim.tick();
  }
  return sim;
}

void main() {
  group('saving a run', () {
    test('carries depth, holdings and the damage on the current layer', () {
      final sim = _played(40)..buyDrill();

      final restored = PrototypeSimulation()..readJson(sim.toJson());

      expect(restored.layer.value, sim.layer.value);
      expect(restored.drills.value, sim.drills.value);
      expect('${restored.regolith.value}', '${sim.regolith.value}');
      expect(
        '${restored.stock.amount(ResourceId.crystals)}',
        '${sim.stock.amount(ResourceId.crystals)}',
      );
      expect(
        '${restored.layerHp.value}',
        '${sim.layerHp.value}',
        reason: 'part-broken rock stays part-broken across a save',
      );
    });

    test('the rolls carry on instead of replaying from the seed', () {
      final sim = _played(20);
      final restored = PrototypeSimulation()..readJson(sim.toJson());

      final expected = [
        for (var i = 0; i < 12; i++) sim.tick().crystalsGained.isZero,
      ];
      final actual = [
        for (var i = 0; i < 12; i++) restored.tick().crystalsGained.isZero,
      ];

      expect(
        actual,
        expected,
        reason:
            'restoring the streams is what stops a save-scummer from '
            'replaying the same drops every load',
      );
    });

    test('layer hp maximum is recomputed rather than read back', () {
      final sim = _played(30);
      final tampered = Map<String, Object?>.from(sim.toJson());
      tampered['layerHp'] = BigDouble.fromNum(1e9).toJson();

      final restored = PrototypeSimulation()..readJson(tampered);

      expect(
        '${restored.layerHpMax.value}',
        '${PrototypeSimulation.densityAt(sim.layer.value)}',
      );
      expect(
        '${restored.layerHp.value}',
        '${restored.layerHpMax.value}',
        reason:
            'damage above the layer maximum is nonsense, so the formula '
            'wins and the layer starts whole',
      );
    });

    test('an empty save reads as a fresh run', () {
      final sim = PrototypeSimulation()..readJson(const {});

      expect(sim.layer.value, 0);
      expect(sim.drills.value, 1);
      expect(sim.energy.value, PrototypeSimulation.energyCapBase);
      expect(sim.stock.amount(ResourceId.regolith).isZero, isTrue);
    });

    test('a strike spends energy and lands the strike power', () {
      final sim = PrototypeSimulation();
      final hpBefore = sim.layerHp.value;

      final outcome = sim.strike();

      expect(outcome.landed, isTrue);
      expect(sim.energy.value, sim.energyCap - 1);
      // The opening layer is softer than a base strike, so the blow breaks
      // through and the leftover carries into the next layer.
      expect(outcome.layersBroken, greaterThan(0));
      expect(
        sim.layerHp.value < sim.layerHpMax.value,
        isTrue,
        reason: 'the carried remainder lands on the newly exposed layer',
      );
      expect('$hpBefore', '${BigDouble.fromNum(5)}');
    });

    test('a strike loots regolith inside the stated band', () {
      final sim = PrototypeSimulation();
      final before = sim.regolith.value;
      final min = sim.strikeRegolithMin;
      final max = sim.strikeRegolithMax;

      final outcome = sim.strike();

      final critMax =
          max * BigDouble.fromNum(PrototypeSimulation.strikeCritPower);
      expect(
        outcome.regolithGained.gteWithTolerance(min) &&
            critMax.gteWithTolerance(outcome.regolithGained),
        isTrue,
        reason:
            'the haul is a roll, but only ever inside the band the loot '
            'table promises, stretched at most by one crit',
      );
      expect(
        sim.regolith.value >= before + min,
        isTrue,
        reason:
            'the strike yield lands in the store on top of any break '
            'bonus the blow also earned',
      );
    });

    test('a strike with no energy does nothing', () {
      final sim = PrototypeSimulation();
      while (sim.energy.value > 0) {
        sim.strike();
      }
      final hpBefore = '${sim.layerHp.value}';

      expect(sim.strike().landed, isFalse);
      expect('${sim.layerHp.value}', hpBefore);
    });

    test('strike power floors at the base with no rig to lean on', () {
      final sim = PrototypeSimulation();
      // One starting drill: 35% of its output is under the floor.
      expect(
        '${sim.strikePower}',
        '${BigDouble.fromNum(PrototypeSimulation.baseStrikePower)}',
      );
    });

    test('breaking a layer by hand pays the break bonus', () {
      final sim = PrototypeSimulation();
      final before = sim.regolith.value;
      var broken = 0;
      while (broken == 0 && sim.energy.value > 0) {
        broken += sim.strike().layersBroken;
      }

      expect(broken, greaterThan(0));
      expect(
        sim.regolith.value > before,
        isTrue,
        reason:
            'broken rock is the reward for striking: the early loop is '
            'break, collect, sell',
      );
    });
  });

  group('an absence', () {
    test('pays expected value at offline pace and leaves depth alone', () {
      final sim = _played(30);
      final layerBefore = sim.layer.value;
      final oreBefore = sim.regolith.value;
      final expectedOre =
          sim.regolithPerCycle.value *
          BigDouble.fromNum(PrototypeSimulation.strikeShareOfRig) *
          BigDouble.fromNum(100) *
          BigDouble.fromNum(PrototypeSimulation.offlineEfficiency);

      final gain = sim.claimOffline(cycles: 100);

      expect(gain.cycles, 100);
      expect('${gain.ore}', '$expectedOre');
      expect('${sim.regolith.value}', '${oreBefore + expectedOre}');
      expect(
        sim.layer.value,
        layerBefore,
        reason: 'drilling is the online game; the store earns, the bit waits',
      );
    });

    test('does not touch the roll streams', () {
      final mirror = _played(20);
      final away = _played(20)..claimOffline(cycles: 5000);

      final expected = [for (var i = 0; i < 8; i++) mirror.tick().critical];
      final actual = [for (var i = 0; i < 8; i++) away.tick().critical];

      expect(
        actual,
        expected,
        reason:
            'expected value instead of rolls is what keeps an absence '
            'from shifting every crit that follows the comeback',
      );
    });

    test('zero or negative cycles pay nothing', () {
      final sim = _played(10);
      final before = '${sim.regolith.value}';

      expect(sim.claimOffline(cycles: 0).isEmpty, isTrue);
      expect(sim.claimOffline(cycles: -3).isEmpty, isTrue);
      expect('${sim.regolith.value}', before);
    });
  });

  group('the migration chain', () {
    test('a v1 save with "ore" loads as regolith', () {
      final codec = SaveCodec(
        currentVersion: 2,
        migrations: [
          SaveMigration(
            fromVersion: 1,
            apply: (sections) {
              final run = Map<String, Object?>.from(sections['run']! as Map);
              final stock = Map<String, Object?>.from(run['stock']! as Map);
              stock['regolith'] = stock.remove('ore');
              run['stock'] = stock;
              return {...sections, 'run': run};
            },
          ),
        ],
      );

      final aged = _played(15);
      final v1Run = Map<String, Object?>.from(aged.toJson());
      final v1Stock = Map<String, Object?>.from(v1Run['stock']! as Map);
      v1Stock['ore'] = v1Stock.remove('regolith');
      v1Run['stock'] = v1Stock;
      final wire = '{"version": 1, "sections": {"run": ${_json(v1Run)}}}';

      final back = codec.decode(wire).sections['run']! as Map<String, Object?>;
      final restored = PrototypeSimulation()..readJson(back);

      expect('${restored.regolith.value}', '${aged.regolith.value}');
    });
  });

  group('the save document', () {
    test('a run survives the codec, not just the map', () {
      final codec = SaveCodec(currentVersion: 1);
      final sim = _played(25);

      final wire = codec.encode(
        SaveDocument(version: 1, sections: {'run': sim.toJson()}),
      );
      final back = codec.decode(wire).sections['run']! as Map<String, Object?>;
      final restored = PrototypeSimulation()..readJson(back);

      expect(restored.layer.value, sim.layer.value);
      expect('${restored.regolith.value}', '${sim.regolith.value}');
    });
  });
}
