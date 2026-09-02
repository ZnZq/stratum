import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The rock face behind a diagram: the stratum's gradient, the stone and
/// crack textures salted over it, and the hairline where the face begins.
/// Both the arm's and the drill's diagrams draw exactly this band.
void paintFaceBand(
  Canvas canvas, {
  required double top,
  required double bottom,
  required double width,
  required int layer,
  required CustomPainter stones,
  required CustomPainter cracks,
}) {
  // Run the face a little past the bottom of the band: a fraction of a
  // pixel of rounding must never read as a gap under the rock.
  final band = Rect.fromLTWH(0, top, width, bottom - top + 6);
  canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Strata.fillFor(layer),
      ).createShader(band),
  );

  canvas.save();
  canvas.translate(0, top);
  canvas.clipRect(Rect.fromLTWH(0, 0, width, band.height));
  stones.paint(canvas, Size(width, band.height));
  cracks.paint(canvas, Size(width, band.height));
  canvas.restore();

  canvas.drawLine(
    Offset(0, top),
    Offset(width, top),
    Paint()
      ..color = const Color(0x33A8C4E0)
      ..strokeWidth = 1,
  );
}
