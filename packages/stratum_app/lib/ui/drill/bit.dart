import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../tokens.dart';
import 'metrics.dart';

import 'package:flutter/foundation.dart';

import 'pipe.dart';
import '../frame_clock.dart';

/// The bit, cutting.
///
/// Two separate motions: the flutes scroll down the cone at their own speed,
/// which doubles under forcing, and the tip heats towards the moment the tick
/// lands. The heat is read from the engine rather than animated on a timer of
/// its own, so the flare peaks exactly when the layer takes the damage.
class DrillBit extends StatefulWidget {
  const DrillBit({required this.engine, this.phase = 0, super.key});

  final TickEngine engine;

  /// Where this bit's flutes start, matched to its own pipe.
  final double phase;

  @override
  State<DrillBit> createState() => DrillBitState();
}

class DrillBitState extends State<DrillBit>
    with SingleTickerProviderStateMixin, FrameClock {
  late final ValueNotifier<double> _flutes = ValueNotifier(widget.phase);
  final ValueNotifier<double> _bite = ValueNotifier(0);

  @override
  void onFrame(double dt, Duration raw) {
    _flutes.value = (_flutes.value + dt / rigFlutePeriod) % 1.0;
    _bite.value = widget.engine.progress;
  }

  @override
  void dispose() {
    _flutes.dispose();
    _bite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(bitWidth, bitHeight),
        painter: BitPainter(flutes: _flutes, bite: _bite),
      ),
    );
  }
}

class BitPainter extends CustomPainter {
  BitPainter({required this.flutes, required this.bite})
    : super(repaint: Listenable.merge([flutes, bite]));

  final ValueListenable<double> flutes;
  final ValueListenable<double> bite;

  static const double _fluteSpacing = 6.5;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = flutes.value;
    final heat = Curves.easeInQuad.transform(bite.value.clamp(0.0, 1.0));
    final tip = Offset(size.width / 2, size.height);

    // The rock glowing where the cone is working, drawn past the bit's own
    // bounds so the heat spills onto the layer below it.
    canvas.drawCircle(
      tip,
      14 + heat * 8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 190, 90, 0.16 + heat * 0.5),
            const Color(0x00EF9F27),
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: 14 + heat * 8)),
    );

    final cone = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(tip.dx, tip.dy)
      ..close();

    // Same round-section shading as the pipe, so the two read as one machine.
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF6B4408),
            Palette.amber,
            Color(0xFFFFF0C8),
            Color(0xFFD08A18),
            Color(0xFF5C3A06),
          ],
          stops: [0, 0.22, 0.4, 0.72, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.save();
    canvas.clipPath(cone);

    final groove = Paint()
      ..strokeWidth = 2.2
      ..color = const Color(0x40000000);
    final relief = Paint()
      ..strokeWidth = 0.9
      ..color = const Color(0x40FFFFFF);
    final slide = phase * _fluteSpacing;
    for (
      var y = -_fluteSpacing;
      y < size.height + _fluteSpacing;
      y += _fluteSpacing
    ) {
      final top = y + slide;
      canvas.drawLine(Offset(0, top), Offset(size.width, top + 5), groove);
      canvas.drawLine(
        Offset(0, top - 1.8),
        Offset(size.width, top + 3.2),
        relief,
      );
    }

    canvas.drawCircle(
      tip,
      4.5 + heat * 3.5,
      Paint()
        ..color = Color.fromRGBO(255, 245, 220, 0.35 + heat * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
    canvas.restore();

    // Carbide teeth along the cutting edges.
    final tooth = Paint()..color = const Color(0xFFEFF3F8);
    final toothShade = Paint()..color = const Color(0x59000000);
    for (var i = 1; i <= 3; i++) {
      final t = i / 4;
      for (final side in const [-1.0, 1.0]) {
        final edge = Offset.lerp(Offset(side < 0 ? 0 : size.width, 0), tip, t)!;
        final out = Offset(side * 2.6, 0.6);
        final path = Path()
          ..moveTo(edge.dx, edge.dy - 1.8)
          ..lineTo(edge.dx + out.dx, edge.dy + out.dy)
          ..lineTo(edge.dx, edge.dy + 1.8)
          ..close();
        canvas.drawPath(path, tooth);
        canvas.drawPath(path.shift(const Offset(0, 0.9)), toothShade);
      }
    }

    // Swarf thrown off the edge, one fleck per flute passing the tip.
    final spark = Paint()
      ..color = Color.fromRGBO(255, 215, 130, 0.25 + heat * 0.55)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final travel = (phase + i / 3) % 1.0;
      final away = 3 + travel * 9;
      final side = i.isEven ? 1.0 : -1.0;
      final from = tip + Offset(side * away * 0.7, away * 0.35);
      canvas.drawLine(from, from + Offset(side * 2.4, 1.2), spark);
    }
  }

  @override
  bool shouldRepaint(BitPainter oldDelegate) => false;
}
