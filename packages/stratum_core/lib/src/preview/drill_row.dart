import 'drill_id.dart';
import '../stockpile.dart';

/// One row of the drill table: what a drill is, before any levels.
class DrillRow {
  const DrillRow(this.id, this.mines, this.label, this.intervalBase);

  final DrillId id;

  /// The one resource this drill brings up.
  final ResourceId mines;

  final String label;

  /// Seconds between cycles before the drive track touches it. A typed drill
  /// starts SLOW on purpose: the drive track's whole lifetime value is
  /// base / floor, so a drill that starts near the floor has nothing to sell.
  final double intervalBase;
}
