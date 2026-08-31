import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'metrics.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class DrillPipe extends StatefulWidget {
  const DrillPipe({this.phase = 0, super.key});

  /// Where this drill's flutes start, so neighbours do not turn in lockstep.
  final double phase;

  @override
  State<DrillPipe> createState() => DrillPipeState();
}

class DrillPipeState extends State<DrillPipe>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<double> _flutes = ValueNotifier(widget.phase);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;
    _flutes.value =
        (_flutes.value + delta.inMicroseconds / 1e6 / rigFlutePeriod) % 1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(pipeWidth, stringLength),
        painter: PipePainter(flutes: _flutes),
      ),
    );
  }
}

const double rigFlutePeriod = 0.4;

class PipePainter extends CustomPainter {
  PipePainter({required this.flutes}) : super(repaint: flutes);

  final ValueListenable<double> flutes;

  static const double _fluteSpacing = 13;
  static const double _collarSpacing = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final barrel = Offset.zero & size;

    // Cross-section shading: the highlight sits left of centre so the pipe
    // reads as round rather than as a flat strip.
    canvas.drawRect(
      barrel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF171A21),
            Color(0xFF6E7787),
            Color(0xFFC3CAD6),
            Color(0xFF7C8595),
            Color(0xFF14171D),
          ],
          stops: [0, 0.2, 0.36, 0.7, 1],
        ).createShader(barrel),
    );

    canvas.save();
    canvas.clipRect(barrel);

    final slide = flutes.value * _fluteSpacing;
    final groove = Paint()
      ..strokeWidth = 3.4
      ..color = const Color(0x33000000);
    final relief = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x2EFFFFFF);
    for (
      var y = -_fluteSpacing;
      y < size.height + _fluteSpacing;
      y += _fluteSpacing
    ) {
      final top = y + slide;
      canvas.drawLine(Offset(0, top), Offset(size.width, top + 9), groove);
      canvas.drawLine(
        Offset(0, top - 2.4),
        Offset(size.width, top + 6.6),
        relief,
      );
    }

    canvas.restore();

    // Collars: the joints between pipe sections.
    final collarEdge = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x73000000);
    for (var y = 7.0; y < size.height; y += _collarSpacing) {
      final collar = Rect.fromLTWH(-2, y, size.width + 4, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(collar, const Radius.circular(2)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF20242D),
              Color(0xFFAEB6C4),
              Color(0xFF565F6E),
              Color(0xFF191D24),
            ],
            stops: [0, 0.34, 0.72, 1],
          ).createShader(collar),
      );
      canvas.drawLine(
        Offset(-2, y + 5.5),
        Offset(size.width + 2, y + 5.5),
        collarEdge,
      );
    }

    final rim = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF0C0E13);
    canvas.drawLine(const Offset(0.5, 0), Offset(0.5, size.height), rim);
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      rim,
    );
  }

  @override
  bool shouldRepaint(PipePainter oldDelegate) => false;
}
