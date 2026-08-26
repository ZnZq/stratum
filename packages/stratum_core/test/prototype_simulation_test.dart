import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

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
      expect('${restored.ore.value}', '${sim.ore.value}');
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

      final expected = [for (var i = 0; i < 12; i++) sim.tick().critical];
      final actual = [for (var i = 0; i < 12; i++) restored.tick().critical];

      expect(
        actual,
        expected,
        reason:
            'restoring the streams is what stops a save-scummer from '
            'replaying the same crits every load',
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
      expect(sim.charge.value, PrototypeSimulation.chargeCap);
      expect(sim.stock.amount(ResourceId.ore).isZero, isTrue);
    });

    test('forcing is never restored: it is a held button', () {
      final sim = _played(5);
      sim.beginForcing();
      expect(sim.forcing.value, isTrue);

      final restored = PrototypeSimulation()..readJson(sim.toJson());

      expect(restored.forcing.value, isFalse);
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
      expect('${restored.ore.value}', '${sim.ore.value}');
    });
  });
}
