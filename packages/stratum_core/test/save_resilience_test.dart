import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// A save with the right shape and wrong values must still load: the
/// backup-and-quarantine path only works if reading never throws past it.
void main() {
  test('corrupt values inside a well-formed save fall back, never throw', () {
    final sim = PrototypeSimulation();
    final json = sim.toJson();
    json['layer'] = 'deep';
    json['layerHp'] = 'not a number';
    json['stock'] = {'regolith': 'abc', 'credits': 12};
    json['random'] = {'garbage': 1};
    json['craft'] = {'last': 'never', 'lines': 'none'};
    json['replicator'] = {'u': 'yes', 'sp.cuprum': 'fast'};

    final back = PrototypeSimulation();
    expect(() => back.readJson(json), returnsNormally);
    expect(back.layer.value, 0);
    expect(back.stock.amount(ResourceId.regolith).isZero, isTrue);
    // A save read is a run to continue: the rolls must still roll.
    expect(() => back.strike(), returnsNormally);
  });

  test('an integral double in a save reads as the int it is', () {
    final sim = PrototypeSimulation();
    final json = sim.toJson();
    json['layer'] = 12.0;
    final back = PrototypeSimulation()..readJson(json);
    expect(back.layer.value, 12);
  });
}
