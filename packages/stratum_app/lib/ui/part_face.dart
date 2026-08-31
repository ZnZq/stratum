import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'part_glyph.dart';
import 'tokens.dart';

/// A part's face: its glyph in a well, with the numeral that ties it to the
/// same numeral on the arm diagram above.
class PartFace extends StatelessWidget {
  const PartFace({
    required this.part,
    required this.mark,
    this.lit = false,
    this.size = 36,
    super.key,
  });

  final ArmPart part;
  final int mark;

  /// Whether the piece is at its ceiling and waiting to be rebuilt.
  final bool lit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final well = size - 4;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: SizedBox(
              width: well,
              height: well,
              child: HudPlate(
                cut: size * 0.24,
                fill: lit ? Palette.goldWell : Palette.shell,
                edge: lit ? Palette.amber : Palette.line,
                child: Center(
                  child: CustomPaint(
                    size: Size(well * 0.62, well * 0.62),
                    painter: PartGlyph(part, mark: mark),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.goldWell,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.amber),
              ),
              child: Text(
                '${part.index + 1}',
                style: AppText.display(
                  size * 0.22,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
