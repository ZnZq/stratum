import 'preview/prototype_simulation.dart';
import 'save_codec.dart';

/// Bumped whenever the shape of a save changes, with a migration to match.
/// A gap in the chain is an error rather than a silent skip -- see
/// [SaveCodec].
const int stratumSaveVersion = 10;

/// The chain from every save ever written to the shape this build reads.
/// Lives in the core so each step can be pinned by a test on its own,
/// instead of in the app where nothing can run it.
final List<SaveMigration> stratumSaveMigrations = [
  // v9 -> v10: the rig stopped being a rung of the automation ladder and
  // became a purchase of its own on the drills screen; its flag moves
  // from the ladder's list to the bores section.
  SaveMigration(
    fromVersion: 9,
    apply: (sections) {
      final run = sections['run'];
      if (run is! Map) return sections;
      final out = Map<String, Object?>.from(run);
      final automation = out['automation'];
      if (automation is! Map) return sections;
      final opened = automation['u'];
      if (opened is! List || !opened.contains('drill')) return sections;
      final bores = out['bores'];
      out['bores'] = {
        ...(bores is Map
            ? Map<String, Object?>.from(bores)
            : <String, Object?>{}),
        'rig': true,
      };
      out['automation'] = {
        ...Map<String, Object?>.from(automation),
        'u': [
          for (final name in opened)
            if (name != 'drill') name,
        ],
      };
      return {...sections, 'run': out};
    },
  ),
  // v8 -> v9: automation became something the player unlocks, and a
  // fresh run starts without the rig. Every save before this had one,
  // so it is granted outright rather than taken away.
  SaveMigration(
    fromVersion: 8,
    apply: (sections) {
      final run = sections['run'];
      if (run is! Map) return sections;
      final out = Map<String, Object?>.from(run);
      final automation = out['automation'];
      final opened = automation is Map && automation['u'] is List
          ? List<Object?>.from(automation['u'] as List)
          : <Object?>[];
      if (!opened.contains('drill')) opened.add('drill');
      out['automation'] = {'u': opened};
      return {...sections, 'run': out};
    },
  ),
  // v7 -> v8: raw data stopped being a computed measurement and became a
  // resource dug out of the rock. The old accumulators are denominated in
  // normalised sightings -- billions of them -- and carrying either one
  // across would trip the collapse gate on the first frame and hand out a
  // wallet nobody earned. Both start over; nothing had been spent from
  // them yet.
  SaveMigration(fromVersion: 7, apply: _dropRunData),
  // v6 -> v7: the peak each part has been BUILT to is a mark, 0..4. Every
  // peak ever written to disk was a LEVEL -- and the build that started
  // reading them as marks clamped, so a peak of 137 landed as 4 and every
  // generation read as already known. There is no way back to the real
  // figure, so it is rebuilt from what the run can prove: the mark the
  // part stands at, or the mark its level has walked into.
  SaveMigration(
    fromVersion: 6,
    apply: (sections) {
      final run = sections['run'];
      if (run is! Map) return sections;
      final arm = run['arm'];
      if (arm is! Map) return sections;
      final out = Map<String, Object?>.from(arm);
      int read(Object? value) => value is num ? value.toInt() : 0;
      for (final part in const ['bit', 'drive', 'supply']) {
        final walked = PrototypeSimulation.generationOf(read(out[part]));
        final built = read(out['${part}Mark']);
        out['${part}Peak'] = walked > built ? walked : built;
      }
      return {
        ...sections,
        'run': {...Map<String, Object?>.from(run), 'arm': out},
      };
    },
  ),
  // v5 -> v6: the manual lane became the manipulator arm. Its three levers
  // were strike power, energy cap and energy regen; they are now three
  // PARTS, and cap and regen merged into one. Strike power carries over to
  // the bit and the old cap level to the supply, which is the closest
  // thing each had; the regen track has no heir and is dropped.
  SaveMigration(
    fromVersion: 5,
    apply: (sections) {
      final run = sections['run'];
      if (run is! Map) return sections;
      final out = Map<String, Object?>.from(run);
      final strikes = out.remove('strikes');
      out['arm'] = {
        'bit': strikes is Map ? strikes['power'] ?? 0 : 0,
        'drive': 0,
        'supply': strikes is Map ? strikes['cap'] ?? 0 : 0,
      };
      return {...sections, 'run': out};
    },
  ),
  // v4 -> v5: data is counted in measurements now, not in tonnes. The old
  // accumulators are in units a thousandfold larger, and keeping them
  // would leave the collapse gate permanently open, so they are dropped
  // and start over -- nothing had been spent from them yet.
  SaveMigration(fromVersion: 4, apply: _dropRunData),
  // v3 -> v4: measurement data arrived (raw, cycle gross, wallet). Purely
  // additive -- absent keys fall back to fresh accumulators -- so the bump
  // only fences old builds off saves they cannot keep whole.
  SaveMigration(fromVersion: 3, apply: (sections) => sections),
  // v2 -> v3: forcing is gone; its charge gauge became energy.
  SaveMigration(
    fromVersion: 2,
    apply: (sections) {
      final run = sections['run'];
      if (run is! Map) return sections;
      final out = Map<String, Object?>.from(run);
      if (out.containsKey('charge')) {
        out['energy'] = out.remove('charge');
      }
      return {...sections, 'run': out};
    },
  ),
  // v1 -> v2: the always-drop stopped being "ore" and became regolith,
  // with the chance ores taking the ore name for themselves.
  SaveMigration(
    fromVersion: 1,
    apply: (sections) {
      Map<String, Object?>? renamed(Object? holder) {
        if (holder is! Map) return null;
        final stock = holder['stock'];
        if (stock is! Map) return null;
        final out = Map<String, Object?>.from(stock);
        if (out.containsKey('ore')) {
          out['regolith'] = out.remove('ore');
        }
        return {...Map<String, Object?>.from(holder), 'stock': out};
      }

      return {
        ...sections,
        'run': ?renamed(sections['run']),
        'meta': ?renamed(sections['meta']),
      };
    },
  ),
];

Map<String, Object?> _dropRunData(Map<String, Object?> sections) {
  final run = sections['run'];
  if (run is! Map) return sections;
  final out = Map<String, Object?>.from(run)..remove('data');
  return {...sections, 'run': out};
}
