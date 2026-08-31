import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'part_glyph.dart';
import 'tokens.dart';

/// A part's piece at one particular mark, in a well of its own.
///
/// The face on a card wears a numeral tying it to the arm above; this one
/// does not, because in the mark ladder the row already says which mark it
/// is. What it does carry is the SHAPE of that mark -- the reason to evolve,
/// stated in metal rather than in a sentence.
class MarkGlyph extends StatelessWidget {
  const MarkGlyph({
    required this.part,
    required this.mark,
    this.lit = false,
    this.hidden = false,
    this.size = 30,
    super.key,
  });

  final ArmPart part;
  final int mark;

  /// The mark the part stands at now.
  final bool lit;

  /// A mark never built: shown as a flat silhouette.
  final bool hidden;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: HudPlate(
        cut: size * 0.24,
        fill: lit ? Palette.goldWell : Palette.shell,
        edge: lit ? Palette.amber : Palette.lineBar,
        child: Center(
          child: CustomPaint(
            size: Size(size * 0.64, size * 0.64),
            painter: PartGlyph(
              part,
              mark: mark,
              tint: hidden ? Palette.line : null,
            ),
          ),
        ),
      ),
    );
  }
}
