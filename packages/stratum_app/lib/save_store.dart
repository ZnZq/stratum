import 'save_slot.dart';
import 'save_summary.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:stratum_core/stratum_core.dart';

/// Save files, on disk.
///
/// Two habits, both from the same failure: a write interrupted by a crash,
/// a kill or a power cut is where corrupt saves overwhelmingly come from.
///
/// * Writes land in a scratch file and are renamed into place, so an
///   interruption costs the new save rather than the old one.
/// * The save being replaced is kept as `.bak` first, so even a rename that
///   somehow lands badly leaves one generation to fall back to.
class SaveStore {
  Directory? _directory;

  Future<Directory> _dir() async =>
      _directory ??= await getApplicationSupportDirectory();

  Future<File> _file(SaveSlot slot) async =>
      File('${(await _dir()).path}${Platform.pathSeparator}${slot.fileName}');

  Future<File> _backup(SaveSlot slot) async =>
      File('${(await _file(slot)).path}.bak');

  /// The live save, or the backup if the live one is gone.
  Future<({String contents, bool fromBackup})?> read(SaveSlot slot) async {
    final file = await _file(slot);
    if (file.existsSync()) {
      return (contents: await file.readAsString(), fromBackup: false);
    }
    final backup = await _backup(slot);
    if (backup.existsSync()) {
      return (contents: await backup.readAsString(), fromBackup: true);
    }
    return null;
  }

  /// Falls back to the backup, used when the live save will not parse.
  Future<String?> readBackup(SaveSlot slot) async {
    final backup = await _backup(slot);
    if (!backup.existsSync()) return null;
    return backup.readAsString();
  }

  Future<void> write(SaveSlot slot, String contents) async {
    final file = await _file(slot);
    if (file.existsSync()) {
      await file.copy((await _backup(slot)).path);
    }
    final scratch = File('${file.path}.writing');
    await scratch.writeAsString(contents, flush: true);
    await scratch.rename(file.path);
  }

  Future<void> delete(SaveSlot slot) async {
    for (final file in [await _file(slot), await _backup(slot)]) {
      if (file.existsSync()) await file.delete();
    }
  }

  /// Moves a save that cannot be read aside instead of deleting it.
  ///
  /// A save the build refuses to parse is still the player's progress, and a
  /// later build may well read it. Overwriting it with a fresh run would be
  /// the one unrecoverable outcome.
  Future<void> quarantine(SaveSlot slot) async {
    final file = await _file(slot);
    if (!file.existsSync()) return;
    await file.rename('${file.path}.unreadable');
  }

  /// Why a slot stayed out of the last [list]: the fault is kept, not
  /// swallowed, so the menu can say why a slot is empty.
  final Map<SaveSlot, String> listFaults = {};

  /// Reads the headline of each slot, skipping any that cannot be read
  /// and recording why in [listFaults].
  Future<List<SaveSummary>> list() async {
    final summaries = <SaveSummary>[];
    listFaults.clear();
    for (final slot in SaveSlot.values) {
      final ({String contents, bool fromBackup})? held;
      try {
        held = await read(slot);
      } on Object catch (error) {
        listFaults[slot] = '$error';
        continue;
      }
      if (held == null) continue;
      final summary = _summarise(slot, held.contents, held.fromBackup);
      if (summary != null) summaries.add(summary);
    }
    return summaries;
  }

  static SaveSummary? _summarise(SaveSlot slot, String raw, bool fromBackup) {
    try {
      final payload = jsonDecode(raw);
      if (payload is! Map) return null;
      final sections = payload['sections'];
      if (sections is! Map) return null;
      final meta = sections['meta'];
      if (meta is! Map) return null;
      final savedAt = DateTime.tryParse('${meta['savedAt']}');
      if (savedAt == null) return null;

      final held = <ResourceId, BigDouble>{};
      final stock = meta['stock'];
      if (stock is Map) {
        for (final id in ResourceId.values) {
          final amount = stock[id.name];
          final parsed = amount is String ? BigDouble.tryParse(amount) : null;
          if (parsed != null) held[id] = parsed;
        }
      }

      return SaveSummary(
        slot: slot,
        savedAt: savedAt,
        depth: _int(meta['depth']),
        drills: _int(meta['drills']),
        drillPower: _int(meta['drillPower']),
        restarts: _int(meta['restarts']),
        playtime: Duration(milliseconds: _int(meta['playedMs'])),
        stock: held,
        fromBackup: fromBackup,
      );
    } on FormatException {
      return null;
    }
  }

  static int _int(Object? value) => value is int ? value : 0;
}
