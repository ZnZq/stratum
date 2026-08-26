import 'dart:convert';

/// Thrown for anything a save file cannot be read as.
class SaveFormatException implements Exception {
  const SaveFormatException(this.message);

  final String message;

  @override
  String toString() => 'SaveFormatException: $message';
}

/// A save at a known schema version: the version plus one entry per subsystem.
///
/// Sections are opaque here. The codec never learns what a section means, which
/// is what lets a new subsystem start saving without touching this file.
class SaveDocument {
  const SaveDocument({required this.version, required this.sections});

  final int version;
  final Map<String, Object?> sections;
}

/// Lifts a save one schema version forward.
///
/// Works on the raw section map, before anything is decoded into domain types.
/// That is the point: the types a migration would need are exactly the ones
/// that changed, so it must not depend on them.
class SaveMigration {
  const SaveMigration({required this.fromVersion, required this.apply});

  final int fromVersion;

  final Map<String, Object?> Function(Map<String, Object?> sections) apply;
}

/// Reads and writes save files, running migrations on the way in.
class SaveCodec {
  SaveCodec({
    required this.currentVersion,
    List<SaveMigration> migrations = const [],
  }) {
    if (currentVersion < 1) {
      throw ArgumentError.value(
        currentVersion,
        'currentVersion',
        'a save version starts at 1',
      );
    }
    for (final migration in migrations) {
      final clash = _migrations.putIfAbsent(
        migration.fromVersion,
        () => migration,
      );
      if (!identical(clash, migration)) {
        throw ArgumentError.value(
          migration.fromVersion,
          'migrations',
          'two migrations claim the same step',
        );
      }
    }
  }

  final int currentVersion;

  final Map<int, SaveMigration> _migrations = {};

  String encode(SaveDocument document) =>
      jsonEncode({'version': currentVersion, 'sections': document.sections});

  SaveDocument decode(String source) {
    final payload = _parse(source);
    final version = _readVersion(payload);
    var sections = _readSections(payload);

    if (version > currentVersion) {
      throw SaveFormatException(
        'the save is from a newer build: version $version, this build reads '
        'up to $currentVersion',
      );
    }

    for (var step = version; step < currentVersion; step++) {
      final migration = _migrations[step];
      if (migration == null) {
        throw SaveFormatException(
          'no migration from version $step, so a version $version save cannot '
          'reach version $currentVersion',
        );
      }
      sections = migration.apply(sections);
    }

    return SaveDocument(version: currentVersion, sections: sections);
  }

  static Map<String, Object?> _parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw SaveFormatException('the save is not valid JSON: ${error.message}');
    }

    if (decoded is! Map<String, Object?>) {
      throw const SaveFormatException('the save must be a JSON object');
    }
    return decoded;
  }

  static int _readVersion(Map<String, Object?> payload) {
    final version = payload['version'];
    if (version is! int) {
      throw const SaveFormatException('the save carries no integer version');
    }
    return version;
  }

  static Map<String, Object?> _readSections(Map<String, Object?> payload) {
    final sections = payload['sections'];
    if (sections is! Map<String, Object?>) {
      throw const SaveFormatException('the save carries no sections object');
    }
    return Map<String, Object?>.from(sections);
  }
}
