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
