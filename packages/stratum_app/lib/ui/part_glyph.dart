import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'tokens.dart';

/// A part of the arm, drawn as the piece it is -- and drawn RICHER the higher
/// its mark.
///
/// The detail is generated from the mark rather than authored five times: a
/// bit gains a flute, a drive a rib, a pack a cell. So evolving is visible on
/// the face itself, and a mark that gets added later needs no new art.
class PartGlyph extends CustomPainter {
  const PartGlyph(this.part, {this.mark = 0, this.tint});

  final ArmPart part;
  final int mark;

  /// Flattens the whole piece into one colour. For a mark the player has
  /// never built: the silhouette says a piece is there, the detail stays the
  /// reward for getting to it.
  final Color? tint;

  /// How many repeated details this mark's piece carries.
  int get _details => mark + 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final steel = Paint()..color = tint ?? const Color(0xFF8794A6);
    final bright = Paint()..color = tint ?? Palette.gold;
    final trim = tint ?? Palette.lineBar;
    final shell = tint ?? Palette.edge;

    switch (part) {
      case ArmPart.bit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 3, 8, 11),
            const Radius.circular(1),
          ),
          steel,
        );
        final flute = Paint()
          ..color = trim
          ..strokeWidth = 1.2;
        for (var i = 0; i < _details; i++) {
          final y = 5 + (9 / (_details + 1)) * (i + 1);
          canvas.drawLine(Offset(8, y), Offset(16, y), flute);
        }
        canvas.drawPath(
          Path()
            ..moveTo(8, 14)
            ..lineTo(16, 14)
            ..lineTo(12, 21)
            ..close(),
          bright,
        );
      case ArmPart.drive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 8, 12, 8),
            const Radius.circular(2),
          ),
          Paint()..color = tint ?? Palette.edge,
        );
        final rib = Paint()
          ..color = trim
          ..strokeWidth = 1.1;
        for (var i = 0; i < _details; i++) {
          final x = 3 + (12 / (_details + 1)) * (i + 1);
          canvas.drawLine(Offset(x, 8), Offset(x, 16), rib);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 10.5, 7, 3),
            const Radius.circular(1.5),
          ),
          bright,
        );
      case ArmPart.supply:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 5, 18, 14),
          const Radius.circular(3),
        );
        canvas.drawRRect(body, Paint()..color = tint ?? Palette.card);
        canvas.drawRRect(
          body,
          Paint()
            ..color = shell
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 8)
            ..lineTo(16, 8)
            ..lineTo(13, 11.5)
            ..lineTo(17, 11.5)
            ..lineTo(11, 17)
            ..lineTo(13, 12.5)
            ..lineTo(9, 12.5)
            ..close(),
          bright,
        );
        for (var i = 0; i < _details; i++) {
          final y = 6.5 + (11 / (_details - 0.001)) * i;
          canvas.drawCircle(Offset(6.5, y), 1.1, Paint()..color = shell);
        }
    }
  }

  @override
  bool shouldRepaint(PartGlyph oldDelegate) =>
      oldDelegate.part != part ||
      oldDelegate.mark != mark ||
      oldDelegate.tint != tint;
}

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
