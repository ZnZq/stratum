import 'dart:convert';

import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// Every step of the save chain, pinned on its own: a save written at
/// version N must read as this build's shape, and the whole chain must
/// end in something the simulation can load.
void main() {
  final codec = SaveCodec(
    currentVersion: stratumSaveVersion,
    migrations: stratumSaveMigrations,
  );

  // Written by hand at the OLD version: encode() stamps the codec's own
  // version, which would skip every step under test.
  SaveDocument migrate(int version, Map<String, Object?> sections) =>
      codec.decode(jsonEncode({'version': version, 'sections': sections}));

  Map<String, Object?> run(SaveDocument document) =>
      Map<String, Object?>.from(document.sections['run'] as Map);

  test('v1 -> ore becomes regolith in the run and in the headline', () {
    final out = migrate(1, {
      'run': {
        'stock': {'ore': '12', 'crystals': '3'},
      },
      'meta': {
        'stock': {'ore': '12'},
      },
    });
    expect(out.version, stratumSaveVersion);
    final stock = run(out)['stock'] as Map;
    expect(stock['regolith'], '12');
    expect(stock.containsKey('ore'), isFalse);
    expect(stock['crystals'], '3');
    final meta = out.sections['meta'] as Map;
    expect((meta['stock'] as Map)['regolith'], '12');
  });

  test('v2 -> the forcing charge becomes energy', () {
    final out = migrate(2, {
      'run': {'charge': 40},
    });
    expect(run(out)['energy'], 40);
    expect(run(out).containsKey('charge'), isFalse);
  });

  test('v3 -> passes through untouched', () {
    final out = migrate(3, {
      'run': {'layer': 9},
    });
    expect(run(out)['layer'], 9);
  });

  test('v4 and v7 -> the old data accumulators are dropped', () {
    for (final version in [4, 7]) {
      final out = migrate(version, {
        'run': {
          'layer': 3,
          'data': {'raw': '1e30'},
        },
      });
      expect(run(out).containsKey('data'), isFalse, reason: 'from v$version');
      expect(run(out)['layer'], 3);
    }
  });

  test('v5 -> the strike levers become the arm parts', () {
    final out = migrate(5, {
      'run': {
        'strikes': {'power': 7, 'cap': 3, 'regen': 9},
      },
    });
    final arm = run(out)['arm'] as Map;
    expect(arm['bit'], 7);
    expect(arm['drive'], 0);
    expect(arm['supply'], 3);
    expect(run(out).containsKey('strikes'), isFalse);
  });

  test('v6 -> peaks are rebuilt from the mark or the walked level', () {
    final out = migrate(6, {
      'run': {
        'arm': {'bit': 150, 'bitMark': 0, 'drive': 5, 'driveMark': 2},
      },
    });
    final arm = run(out)['arm'] as Map;
    // Level 150 has walked into Mk II; the mark was never rebuilt.
    expect(arm['bitPeak'], PrototypeSimulation.generationOf(150));
    // A mark above the walked level wins.
    expect(arm['drivePeak'], 2);
    expect(arm['supplyPeak'], 0);
  });

  test('the whole chain lands on a run the simulation can read', () {
    final out = migrate(1, {
      'run': {
        'layer': 5,
        'charge': 12,
        'stock': {'ore': '99'},
        'strikes': {'power': 2, 'cap': 1},
        'data': {'raw': '1e30'},
      },
    });
    final sim = PrototypeSimulation();
    expect(() => sim.readJson(run(out)), returnsNormally);
    expect(sim.layer.value, 5);
    expect(sim.energy.value, 12);
    expect(sim.regolith.value.toDouble(), 99);
    expect(sim.bitLevel.value, 2);
    expect(sim.rawData.value.isZero, isTrue);
  });
}
