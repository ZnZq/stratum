import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'tokens.dart';

/// A part of the arm, drawn as the piece it is -- and drawn RICHER the higher
/// its mark.
///
/// The detail is generated from the mark rather than authored five times: a
/// bit gains a flute, a drive a rib, a pack a cell. So evolving is visible on
/// the face itself, and a mark that gets added later needs no new art.
class PartGlyph extends CustomPainter {
  const PartGlyph(this.part, {this.mark = 0});

  final ArmPart part;
  final int mark;

  /// How many repeated details this mark's piece carries.
  int get _details => mark + 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final steel = Paint()..color = const Color(0xFF8794A6);
    final bright = Paint()..color = Palette.gold;

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
          ..color = Palette.lineBar
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
          Paint()..color = Palette.edge,
        );
        final rib = Paint()
          ..color = Palette.lineBar
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
        canvas.drawRRect(body, Paint()..color = Palette.card);
        canvas.drawRRect(
          body,
          Paint()
            ..color = Palette.edge
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
          canvas.drawCircle(Offset(6.5, y), 1.1, Paint()..color = Palette.edge);
        }
    }
  }

  @override
  bool shouldRepaint(PartGlyph oldDelegate) =>
      oldDelegate.part != part || oldDelegate.mark != mark;
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
            child: Container(
              width: well,
              height: well,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: lit ? Palette.goldWell : Palette.shell,
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: lit ? Palette.amber : Palette.line),
              ),
              child: CustomPaint(
                size: Size(well * 0.62, well * 0.62),
                painter: PartGlyph(part, mark: mark),
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
