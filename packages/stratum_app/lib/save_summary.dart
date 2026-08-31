import 'save_slot.dart';

import 'package:stratum_core/stratum_core.dart';

/// What a slot says about itself without the game being loaded from it.
///
/// Read from the save's own `meta` section, so the menu can describe a run it
/// is not going to start.
class SaveSummary {
  const SaveSummary({
    required this.slot,
    required this.savedAt,
    required this.depth,
    required this.drills,
    required this.drillPower,
    required this.restarts,
    required this.playtime,
    required this.stock,
    required this.fromBackup,
  });

  final SaveSlot slot;
  final DateTime savedAt;
  final int depth;
  final int drills;
  final int drillPower;
  final int restarts;
  final Duration playtime;
  final Map<ResourceId, BigDouble> stock;

  /// Whether the live file was unreadable and this came off the backup.
  final bool fromBackup;

  BigDouble amount(ResourceId id) => stock[id] ?? BigDouble.zero;
}
