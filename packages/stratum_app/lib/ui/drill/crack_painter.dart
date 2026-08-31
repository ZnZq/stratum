import 'package:flutter/widgets.dart';

import 'dart:math' as math;

import 'noise.dart';

class CrackPainter extends CustomPainter {
  const CrackPainter(this.damage, {required this.layer});

  final double damage;

  /// Seeds this layer's own fracture pattern: every metre breaks its own way
  /// instead of replaying one memorised set of cracks.
  final int layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    // A fracture NETWORK, not a handful of lines: a few long primaries cross
    // the layer first, branches split the pieces they made, and short twigs
    // crumble the pieces further. Revealed in that order by damage, the layer
    // visibly falls apart into fragments rather than just collecting scars.
    final seed = Noise(layer * 977 + 41);

    List<Offset> walk(Offset from, double angle, int segments, double step) {
      final points = [from];
      var at = from;
      var heading = angle;
      for (var i = 0; i < segments; i++) {
        heading += (seed.next() - 0.5) * 1.2;
        at += Offset(math.cos(heading) * step, math.sin(heading) * step * 0.55);
        points.add(at);
      }
      return points;
    }

    final cracks = <({List<Offset> points, double width})>[];

    // Seven waves over a jittered grid. The grid keeps every wave spread
    // evenly across the whole face -- no corner shatters while another sits
    // untouched -- and each wave lays finer, shorter cracks than the last.
    // Within a wave the cells come in a shuffled order, so a part-broken
    // layer is evenly peppered rather than filling like a progress bar; by
    // the last wave the face is crazed everywhere.
    const waves = 7;
    final cols = math.max(4, (size.width / 52).round());
    final rows = math.max(2, (size.height / 20).round());
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final cellCount = cols * rows;

    for (var wave = 0; wave < waves && cracks.length < 84; wave++) {
      final width = 1.7 * math.pow(0.85, wave).toDouble();
      final step = size.width * 0.030 * math.pow(0.8, wave).toDouble();
      final segments = wave < 2 ? 4 : (wave < 5 ? 3 : 2);

      final keys = List<double>.generate(cellCount, (_) => seed.next());
      final order = List<int>.generate(cellCount, (i) => i)
        ..sort((a, b) => keys[a].compareTo(keys[b]));

      for (final cell in order) {
        if (cracks.length >= 84) break;
        final from = Offset(
          (cell % cols + 0.15 + seed.next() * 0.7) * cellWidth,
          (cell ~/ cols + 0.15 + seed.next() * 0.7) * cellHeight,
        );
        cracks.add((
          points: walk(
            from,
            seed.next() * math.pi * 2,
            segments,
            step * (0.8 + seed.next() * 0.5),
          ),
          width: width,
        ));
      }
    }

    final split = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < cracks.length; i++) {
      final opacity = (damage * cracks.length - i).clamp(0.0, 1.0);
      if (opacity <= 0.03) continue;

      final crack = cracks[i];
      final path = Path()..moveTo(crack.points.first.dx, crack.points.first.dy);
      for (final point in crack.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }

      split.strokeWidth = crack.width;
      lip.strokeWidth = crack.width * 0.55;
      lip.color = Color.fromRGBO(255, 255, 255, opacity * 0.18);
      split.color = Color.fromRGBO(0, 0, 0, opacity * 0.6);
      canvas.save();
      canvas.translate(0.8, 0.9);
      canvas.drawPath(path, lip);
      canvas.restore();
      canvas.drawPath(path, split);
    }
  }

  @override
  bool shouldRepaint(CrackPainter oldDelegate) =>
      oldDelegate.damage != damage || oldDelegate.layer != layer;
}
