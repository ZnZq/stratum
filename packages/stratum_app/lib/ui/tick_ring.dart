import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'tokens.dart';

/// The arc that fills between ticks, plus the drill head it wraps.
///
/// The engine owns the truth about how far the current interval has been
/// served; this only asks it once per frame. Running an independent animation
/// of the same duration would drift the moment the rate changes for forcing or
/// the app comes back from the background.
class TickRing extends StatefulWidget {
  const TickRing({required this.engine, this.diameter = 96, super.key});

  final TickEngine engine;
  final double diameter;

  @override
  State<TickRing> createState() => _TickRingState();
}

class _TickRingState extends State<TickRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier(0);
  final ValueNotifier<double> _spin = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;

    _progress.value = widget.engine.progress;

    // The gear turns once every 2.6s, the prototype's resting spin.
    _spin.value = (_spin.value + delta.inMicroseconds / 1e6 / 2.6) % 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size(widget.diameter, widget.diameter),
              painter: _RingPainter(_progress),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _spin,
            builder: (context, turns, child) =>
                Transform.rotate(angle: turns * 2 * math.pi, child: child),
            child: Icon(
              const IconData(0xf5ac, fontFamily: 'TablerIcons'),
              size: widget.diameter * 0.31,
              color: Palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress) : super(repaint: progress);

  final ValueNotifier<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Derived from the box rather than fixed, so the ring can be sized to
    // whatever it is wrapping instead of only to the head it started on.
    final radius = size.shortestSide / 2 - 8;
    final stroke = size.shortestSide / 19;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Palette.line;
    canvas.drawCircle(centre, radius, track);

    final swept = progress.value.clamp(0.0, 1.0);
    if (swept <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Palette.amber;
    canvas.drawArc(rect, -math.pi / 2, swept * 2 * math.pi, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
