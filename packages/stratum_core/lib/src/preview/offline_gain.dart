import '../big_double.dart';
import '../stockpile.dart';

/// What an absence paid out.
class OfflineGain {
  const OfflineGain({
    required this.seconds,
    required this.cycles,
    required this.efficiency,
    required this.gained,
  });

  static const OfflineGain none = OfflineGain(
    seconds: 0,
    cycles: 0,
    efficiency: 0,
    gained: {},
  );

  /// How long the player was away.
  final double seconds;

  /// The same span counted in drill cycles, for a readout that speaks in
  /// heartbeats rather than in seconds.
  final int cycles;

  final double efficiency;

  /// Everything earned, by resource. One flat map for the same reason the
  /// stockpile is one: a resource added later is an entry here, not a new
  /// field wired into every place that shows the haul.
  final Map<ResourceId, BigDouble> gained;

  bool get isEmpty => gained.isEmpty;
}
