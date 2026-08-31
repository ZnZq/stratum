import '../big_double.dart';
import '../stockpile.dart';

/// What one manual strike did.
class StrikeOutcome {
  const StrikeOutcome({
    required this.spent,
    required this.layersBroken,
    required this.thickLayersBroken,
    required this.regolithGained,
    required this.oresGained,
    required this.critical,
  });

  static const StrikeOutcome none = StrikeOutcome(
    spent: 0,
    layersBroken: 0,
    thickLayersBroken: 0,
    regolithGained: BigDouble.zero,
    oresGained: {},
    critical: false,
  );

  final int spent;
  final int layersBroken;
  final int thickLayersBroken;
  final BigDouble regolithGained;

  /// Whether this blow critted, multiplying its damage and haul alike.
  final bool critical;

  /// The chance ores this blow happened to shake loose.
  final Map<ResourceId, BigDouble> oresGained;

  bool get landed => spent > 0;
}
