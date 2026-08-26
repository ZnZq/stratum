import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

SaveCodec codecAt(int version, [List<SaveMigration> migrations = const []]) =>
    SaveCodec(currentVersion: version, migrations: migrations);

void main() {
  group('round trip', () {
    test('carries sections there and back', () {
      final codec = codecAt(1);
      final document = SaveDocument(
        version: 1,
        sections: {
          'rng': {'seed': 42},
          'drilling': {'depth': 17},
        },
      );

      final restored = codec.decode(codec.encode(document));

      expect(restored.version, 1);
      expect(restored.sections['rng'], {'seed': 42});
      expect(restored.sections['drilling'], {'depth': 17});
    });

    test('stamps the codec version when encoding', () {
      final encoded = codecAt(3).encode(SaveDocument(version: 3, sections: {}));

      expect(codecAt(3).decode(encoded).version, 3);
    });

    test('survives an empty save', () {
      final codec = codecAt(1);

      expect(
        codec
            .decode(codec.encode(SaveDocument(version: 1, sections: {})))
            .sections,
        isEmpty,
      );
    });

    test('carries a real RandomSource through', () {
      final codec = codecAt(1);
      final source = RandomSource(seed: 99);
      source.stream('crit').nextDouble();

      final encoded = codec.encode(
        SaveDocument(version: 1, sections: {'rng': source.toJson()}),
      );
      final restored = RandomSource.fromJson(
        codec.decode(encoded).sections['rng']! as Map<String, dynamic>,
      );

      expect(
        restored.stream('crit').nextDouble(),
        source.stream('crit').nextDouble(),
      );
    });
  });

  group('migrations', () {
    test('lifts an older save to the current version', () {
      final codec = codecAt(2, [
        SaveMigration(
          fromVersion: 1,
          apply: (sections) => {...sections, 'added': 'by migration'},
        ),
      ]);
      final old = codecAt(1)
          .encode(SaveDocument(version: 1, sections: {'kept': 'original'}));

      final restored = codec.decode(old);

      expect(restored.version, 2);
      expect(restored.sections['kept'], 'original');
      expect(restored.sections['added'], 'by migration');
    });

    test('runs a chain in order across several versions', () {
      final trail = <int>[];
      final codec = codecAt(4, [
        SaveMigration(
          fromVersion: 1,
          apply: (s) {
            trail.add(1);
            return s;
          },
        ),
        SaveMigration(
          fromVersion: 2,
          apply: (s) {
            trail.add(2);
            return s;
          },
        ),
        SaveMigration(
          fromVersion: 3,
          apply: (s) {
            trail.add(3);
            return s;
          },
        ),
      ]);
      final old = codecAt(1).encode(SaveDocument(version: 1, sections: {}));

      expect(codec.decode(old).version, 4);
      expect(trail, [1, 2, 3]);
    });

    test('accepts migrations registered out of order', () {
      final trail = <int>[];
      final codec = codecAt(3, [
        SaveMigration(
          fromVersion: 2,
          apply: (s) {
            trail.add(2);
            return s;
          },
        ),
        SaveMigration(
          fromVersion: 1,
          apply: (s) {
            trail.add(1);
            return s;
          },
        ),
      ]);

      codec.decode(codecAt(1).encode(SaveDocument(version: 1, sections: {})));

      expect(trail, [1, 2]);
    });

    test('runs nothing when the save is already current', () {
      var ran = false;
      final codec = codecAt(2, [
        SaveMigration(
          fromVersion: 1,
          apply: (s) {
            ran = true;
            return s;
          },
        ),
      ]);

      codec.decode(codecAt(2).encode(SaveDocument(version: 2, sections: {})));

      expect(ran, isFalse);
    });

    test('a migration can drop a section', () {
      final codec = codecAt(2, [
        SaveMigration(
          fromVersion: 1,
          apply: (sections) => {...sections}..remove('obsolete'),
        ),
      ]);
      final old = codecAt(
        1,
      ).encode(SaveDocument(version: 1, sections: {'obsolete': 1, 'kept': 2}));

      final restored = codec.decode(old);

      expect(restored.sections.containsKey('obsolete'), isFalse);
      expect(restored.sections['kept'], 2);
    });

    test('a gap in the chain is reported, not silently skipped', () {
      final codec = codecAt(3, [
        SaveMigration(fromVersion: 1, apply: (s) => s),
      ]);
      final old = codecAt(1).encode(SaveDocument(version: 1, sections: {}));

      expect(
        () => codec.decode(old),
        throwsA(
          isA<SaveFormatException>().having(
            (e) => e.message,
            'message',
            contains('2'),
          ),
        ),
      );
    });

    test('rejects two migrations claiming the same step', () {
      expect(
        () => codecAt(3, [
          SaveMigration(fromVersion: 1, apply: (s) => s),
          SaveMigration(fromVersion: 1, apply: (s) => s),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('unknown sections', () {
    test('are preserved rather than dropped', () {
      // Running an older build must not quietly erase the progress a newer one
      // wrote, so anything the codec does not recognise passes through intact.
      final codec = codecAt(1);
      final encoded = codec.encode(
        SaveDocument(
          version: 1,
          sections: {
            'from_the_future': {'nested': true},
          },
        ),
      );

      expect(codec.decode(encoded).sections['from_the_future'], {
        'nested': true,
      });
    });

    test('survive a migration that ignores them', () {
      final codec = codecAt(2, [
        SaveMigration(fromVersion: 1, apply: (s) => {...s, 'touched': true}),
      ]);
      final old = codecAt(1)
          .encode(SaveDocument(version: 1, sections: {'stranger': 'value'}));

      expect(codec.decode(old).sections['stranger'], 'value');
    });
  });

  group('refusals', () {
    test('a save from a newer build is refused with its version named', () {
      final future = codecAt(9).encode(SaveDocument(version: 9, sections: {}));

      expect(
        () => codecAt(2).decode(future),
        throwsA(
          isA<SaveFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('9'), contains('2')),
          ),
        ),
      );
    });

    test('malformed text is refused', () {
      expect(
        () => codecAt(1).decode('not json at all'),
        throwsA(isA<SaveFormatException>()),
      );
      expect(() => codecAt(1).decode(''), throwsA(isA<SaveFormatException>()));
    });

    test('a payload that is not an object is refused', () {
      expect(
        () => codecAt(1).decode('[1, 2, 3]'),
        throwsA(isA<SaveFormatException>()),
      );
    });

    test('a missing version is refused', () {
      expect(
        () => codecAt(1).decode('{"sections": {}}'),
        throwsA(isA<SaveFormatException>()),
      );
    });

    test('a non-integer version is refused', () {
      expect(
        () => codecAt(1).decode('{"version": "one", "sections": {}}'),
        throwsA(isA<SaveFormatException>()),
      );
    });

    test('missing sections are refused', () {
      expect(
        () => codecAt(1).decode('{"version": 1}'),
        throwsA(isA<SaveFormatException>()),
      );
    });

    test('rejects a non-positive current version', () {
      expect(() => codecAt(0), throwsArgumentError);
    });
  });

  group('the encoded form stays readable', () {
    test('is plain JSON with the version up front', () {
      final encoded = codecAt(1).encode(
        SaveDocument(
          version: 1,
          sections: {
            'rng': {'seed': 42},
          },
        ),
      );

      expect(encoded, startsWith('{"version":1'));
      expect(encoded, contains('"seed":42'));
    });
  });
}
