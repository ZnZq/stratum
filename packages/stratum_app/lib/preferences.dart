import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// What the player set up around the game, as opposed to what they played.
///
/// Deliberately NOT in the save. A save is the run: depth, holdings, the state
/// of the machines. Which screen was open is a property of the person at the
/// keyboard, not of the simulation -- putting it in a slot would mean loading
/// an old save could move the camera, and that two slots could disagree about
/// where "here" is.
///
/// One small file beside the saves, best-effort throughout: a preference that
/// cannot be read is a preference the game does without, never an error the
/// player has to see.
class Preferences {
  Preferences({this.fileName = 'stratum_ui.json'});

  final String fileName;

  Map<String, Object?> _held = {};
  bool _loaded = false;
  File? _file;

  Future<File> _open() async {
    final dir = await getApplicationSupportDirectory();
    return _file ??= File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _open();
      if (!file.existsSync()) return;
      final read = jsonDecode(await file.readAsString());
      if (read is Map) _held = Map<String, Object?>.from(read);
    } on Object catch (error) {
      debugPrint('preferences could not be read: $error');
    }
  }

  Object? operator [](String key) => _held[key];

  /// Writes the whole file. It holds a handful of keys, so there is nothing
  /// to gain from anything cleverer, and a rewrite can never leave the file
  /// half-updated the way a patch could.
  Future<void> set(String key, Object? value) async {
    if (_held[key] == value) return;
    if (value == null) {
      _held.remove(key);
    } else {
      _held[key] = value;
    }
    try {
      await (await _open()).writeAsString(jsonEncode(_held));
    } on Object catch (error) {
      debugPrint('preferences could not be written: $error');
    }
  }
}
