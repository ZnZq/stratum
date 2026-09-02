import 'package:stratum_core/stratum_core.dart';

/// What a floating caption over the face says and where it lands.
///
/// Presentation, kept out of the coordinator: the game reports an EVENT
/// (a thick layer broke, an echo fired, a crit landed) and this table
/// turns it into words, a colour and a spot on the scene.
class FloatCue {
  const FloatCue({
    required this.text,
    required this.color,
    required this.left,
    required this.top,
    required this.size,
  });

  final String text;
  final int color;
  final double left;
  final double top;
  final double size;

  static FloatCue thickLayer() => const FloatCue(
    text: 'ТОВСТИЙ ШАР · всі ресурси ×${PrototypeSimulation.thickSpan}',
    color: 0xFFFFD782,
    left: 28,
    top: 42,
    size: 16,
  );

  static const FloatCue echo = FloatCue(
    text: 'ехо · подвійний удар',
    color: 0xFF9FE1CB,
    left: 104,
    top: 70,
    size: 14,
  );

  /// The strike's crit, one quiet word scattered over the face by [salt]
  /// so ten a second do not stack into one.
  static FloatCue crit(int salt) => FloatCue(
    text: 'крит',
    color: 0xB3FFD782,
    left: 96 + (salt * 37 % 150).toDouble(),
    top: 118 + (salt * 17 % 46).toDouble(),
    size: 11,
  );
}
