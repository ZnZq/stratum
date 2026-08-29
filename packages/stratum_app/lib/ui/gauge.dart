import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Every bar in the game, drawn by one painter.
///
/// There were four: a painter for the energy sweep, one bar on the shell, one
/// under each arm part, and one across the metre being drilled. They had
/// drifted into four radii, three track colours and two ways of drawing the
/// same fill, and a fifth panel would have added a fifth.
///
/// Flutter's own [LinearProgressIndicator] is not the answer here: it lives in
/// Material, which this app does not import anywhere, and it would bring a
/// Theme, its own animation curve and its own colour opinions along for a bar
/// four pixels tall.
class ProgressPainter extends CustomPainter {
  ProgressPainter({
    required this.value,
    required this.track,
    this.fill,
    this.gradient,
    this.radius,
    this.minSliver = 0,
  }) : super(repaint: value);

  /// How full, 0 to 1. A listenable rather than a number so a gauge that
  /// moves every frame -- the energy sweep -- repaints without rebuilding
  /// anything; a still one passes a constant and never notifies.
  final ValueListenable<double> value;

  /// The empty part. Transparent for a bar laid over something already dark
  /// enough to read the fill against.
  final Color track;

  /// The full part. [gradient] wins when both are given.
  final Color? fill;
  final Gradient? gradient;

  /// Corner radius, or null for a pill.
  final double? radius;

  /// The least the fill may shrink to while still being above zero, so a
  /// gauge at almost-nothing still reads as a gauge and not as a missing
  /// element.
  final double minSliver;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Radius.circular(radius ?? size.height / 2);
    final whole = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(whole, corner),
      Paint()..color = track,
    );

    var fraction = value.value.clamp(0.0, 1.0);
    if (fraction > 0 && fraction < minSliver) fraction = minSliver;
    if (fraction <= 0) return;

    final paint = Paint();
    if (gradient case final gradient?) {
      // Shaded across the WHOLE bar, not across the filled part: a gradient
      // rescaled to the fill would change colour as the bar moved.
      paint.shader = gradient.createShader(whole);
    } else {
      paint.color = fill ?? Palette.gold;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * fraction, size.height),
        corner,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(ProgressPainter old) =>
      old.track != track ||
      old.fill != fill ||
      old.gradient != gradient ||
      old.radius != radius ||
      old.minSliver != minSliver;
}

/// A bar, with an optional reading written across it.
class Gauge extends StatelessWidget {
  /// A bar that only changes when something rebuilds it.
  Gauge({
    required double fraction,
    this.height = 5,
    this.radius,
    this.track = Palette.shell,
    this.fill,
    this.gradient,
    this.label,
    this.minSliver = 0,
    super.key,
  }) : value = AlwaysStoppedAnimation(fraction);

  /// A bar that moves on its own. The listenable drives the painter directly,
  /// so a per-frame gauge costs a repaint rather than a rebuild.
  const Gauge.live({
    required this.value,
    this.height = 5,
    this.radius,
    this.track = Palette.shell,
    this.fill,
    this.gradient,
    this.label,
    this.minSliver = 0,
    super.key,
  });

  final ValueListenable<double> value;
  final double height;
  final double? radius;
  final Color track;
  final Color? fill;
  final Gradient? gradient;
  final double minSliver;

  /// Drawn centred over the bar. For a gauge that states its own reading
  /// rather than needing a caption beside it.
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final bar = CustomPaint(
      painter: ProgressPainter(
        value: value,
        track: track,
        fill: fill,
        gradient: gradient,
        radius: radius,
        minSliver: minSliver,
      ),
    );
    return SizedBox(
      height: height,
      child: label == null
          ? bar
          : Stack(
              fit: StackFit.expand,
              children: [
                bar,
                Center(child: label),
              ],
            ),
    );
  }
}
