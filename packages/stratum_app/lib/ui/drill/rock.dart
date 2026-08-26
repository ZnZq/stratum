/// The borehole wall: the layers themselves, their texture and their cracks.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../tokens.dart';
import 'metrics.dart';

class Rock extends StatelessWidget {
  const Rock({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: game.sim.layer.value.toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, position, _) =>
            _build(constraints.maxHeight, position),
      ),
    );
  }

  Widget _build(double height, double position) {
    final sim = game.sim;
    final current = sim.layer.value;

    // The window of rendered layers follows the animated position, and the
    // camera offset is measured from the first of them. As the position crosses
    // an integer the window steps down and the offset steps back by exactly as
    // much, so the two cancel and the descent stays continuous instead of
    // restarting every metre.
    //
    // Every metre is one [layerHeight] tall whether or not it is its own
    // layer, which is what lets the offset be a plain multiplication: a thick
    // layer is one tile three metres tall, not a tall single metre.
    final first = PrototypeSimulation.layerStart(position.floor());
    final travelled = (position - first) * layerHeight;

    var last = current;
    var tiles = 0;
    var filled = 0.0;
    while ((filled < height || tiles < layersBelow) && tiles < 64) {
      last = PrototypeSimulation.nextLayer(last);
      filled += heightOf(last);
      tiles++;
    }

    final hpFraction = (sim.layerHp.value / sim.layerHpMax.value)
        .toDouble()
        .clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // Applied straight, with no tween of its own: the offset steps by a
          // whole layer at each crossing, and that step is exactly what the
          // shifted window of layers cancels out. Easing it would undo the
          // cancellation and make the descent lurch.
          child: Transform.translate(
            offset: Offset(0, rockTop - travelled),
            child: Column(
              children: [
                for (
                  var i = first;
                  i <= last;
                  i = PrototypeSimulation.nextLayer(i)
                )
                  SizedBox(
                    height: heightOf(i),
                    child: i == current
                        ? HitShake(
                            trigger: game.hitShakes,
                            child: LayerTile(
                              layer: i,
                              isCurrent: true,
                              isPast: false,
                              hpFraction: hpFraction,
                            ),
                          )
                        : LayerTile(
                            layer: i,
                            isCurrent: false,
                            isPast: i < current,
                            hpFraction: hpFraction,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A short shudder every time the face takes a blow.
///
/// Keyed by the trigger count, so each hit restarts the jolt from full and a
/// burst of strikes reads as a rattle rather than one long wobble. Decay is in
/// the amplitude: the tile always comes to rest exactly where it was.
class HitShake extends StatelessWidget {
  const HitShake({required this.trigger, required this.child, super.key});

  final ValueListenable<int> trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: trigger,
      builder: (context, count, child) {
        if (count == 0) return child!;
        return TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (context, t, child) {
            final calm = 1 - t;
            return Transform.translate(
              offset: Offset(
                math.sin(t * math.pi * 4) * 2.6 * calm,
                math.sin(t * math.pi * 3 + 1) * 1.4 * calm,
              ),
              child: child,
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

class LayerTile extends StatelessWidget {
  const LayerTile({
    required this.layer,
    required this.isCurrent,
    required this.isPast,
    required this.hpFraction,
    super.key,
  });

  final int layer;
  final bool isCurrent;
  final bool isPast;
  final double hpFraction;

  @override
  Widget build(BuildContext context) {
    final thick = PrototypeSimulation.isThick(layer);
    final fill = thick ? Palette.thickLayer : Strata.fillFor(layer);
    final opacity = isPast ? 0.38 : (isCurrent ? 1.0 : 0.88);
    final damage = 1 - hpFraction;
    final labelled = (layer + 1) % 5 == 0;

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
          border: Border(
            top: BorderSide(
              color: thick ? Palette.gold : const Color(0x33A8C4E0),
              width: thick ? 2 : 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: StonePainter(layer: layer, thick: thick),
                ),
              ),
            ),
            if (isCurrent)
              Positioned.fill(
                child: CustomPaint(painter: CrackPainter(damage)),
              ),
            // The depth rail: a tick at every metre, a longer one with a
            // reading every fifth. An instrument scale rather than a caption
            // repeated on every layer.
            Positioned(
              left: 0,
              top: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: labelled ? 18 : 9,
                    height: 1,
                    color: labelled
                        ? const Color(0x997FD9C4)
                        : const Color(0x4D7FD9C4),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 6,
              child: Text(
                thick
                    ? '${layer + 1}–${layer + PrototypeSimulation.thickSpan} м'
                    : '${layer + 1} м',
                style: AppText.display(
                  10,
                  color: labelled ? Palette.tech : const Color(0x8CE8E9EE),
                  shadows: true,
                ),
              ),
            ),
            if (thick)
              Positioned(
                left: 12,
                top: 10,
                right: 12,
                child: Text(
                  'ТОВСТИЙ ШАР · всі ресурси '
                  '×${PrototypeSimulation.thickSpan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    11.5,
                    weight: FontWeight.w700,
                    color: Palette.gold,
                    shadows: true,
                  ),
                ),
              ),
            if (isCurrent)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: hpFraction,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Palette.amber, Palette.gold],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grain, clasts and bedding planes, so a layer reads as broken stone rather
/// than a panel filled with one colour.
///
/// Everything is derived from the metre number, so a given layer always looks
/// the same and the texture does not crawl while the camera descends.
class StonePainter extends CustomPainter {
  const StonePainter({required this.layer, required this.thick});

  final int layer;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final noise = Noise((layer + 1) * 9176 + 7);

    // Clasts: the angular chunks that separate stone from soil.
    final clasts = 2 + (size.height / 22).floor();
    final clastLight = Paint()..color = const Color(0x17FFFFFF);
    final clastDark = Paint()..color = const Color(0x1E000000);
    final clastEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x15FFFFFF);
    for (var i = 0; i < clasts; i++) {
      final centre = Offset(
        noise.next() * size.width,
        noise.next() * size.height,
      );
      final radius = 4 + noise.next() * math.min(13, size.height * 0.4);
      final path = Path();
      const sides = 7;
      for (var s = 0; s < sides; s++) {
        final angle = s / sides * math.pi * 2 + noise.next() * 0.5;
        final reach = radius * (0.45 + noise.next() * 0.75);
        final point =
            centre +
            Offset(math.cos(angle) * reach, math.sin(angle) * reach * 0.62);
        if (s == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, noise.next() < 0.5 ? clastLight : clastDark);
      canvas.drawPath(path, clastEdge);
    }

    // Bedding planes: the seams the rock splits along.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0x1C000000);
    final seams = 1 + (size.height / 34).floor();
    for (var i = 0; i < seams; i++) {
      final y = noise.next() * size.height;
      final path = Path()..moveTo(0, y);
      final step = size.width / 4;
      for (var x = step; x <= size.width + 0.5; x += step) {
        path.lineTo(x, y + (noise.next() - 0.5) * 5);
      }
      canvas.drawPath(path, seam);
    }

    // Grain.
    final light = Paint()..color = const Color(0x22FFFFFF);
    final dark = Paint()..color = const Color(0x26000000);
    final grains = (size.width * size.height / 560).round();
    for (var i = 0; i < grains; i++) {
      canvas.drawCircle(
        Offset(noise.next() * size.width, noise.next() * size.height),
        0.5 + noise.next() * 1.4,
        noise.next() < 0.45 ? light : dark,
      );
    }

    if (thick) {
      final vein = Paint()..color = const Color(0x59FFD782);
      for (var i = 0; i < 26; i++) {
        canvas.drawCircle(
          Offset(noise.next() * size.width, noise.next() * size.height),
          0.6 + noise.next() * 1.1,
          vein,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StonePainter oldDelegate) =>
      oldDelegate.layer != layer || oldDelegate.thick != thick;
}

/// A tiny deterministic sequence, so texture is a function of depth.
class Noise {
  Noise(this._state);

  int _state;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

/// Where cracks sit on a layer and how they lie.
///
/// Everything is a fraction: position of the layer, length of its width. The
/// prototype stated these in pixels against a 96px layer, which stopped working
/// the moment layers got thinner -- a rotated 70px line simply left the tile.
const List<({double x, double y, double turn, double length})> cracks = [
  (x: 0.16, y: 0.20, turn: 62, length: 0.133),
  (x: 0.52, y: 0.44, turn: -34, length: 0.169),
  (x: 0.30, y: 0.64, turn: 10, length: 0.144),
  (x: 0.68, y: 0.14, turn: 78, length: 0.113),
  (x: 0.08, y: 0.46, turn: -64, length: 0.123),
  (x: 0.44, y: 0.08, turn: 24, length: 0.179),
  (x: 0.78, y: 0.56, turn: -12, length: 0.108),
];

class CrackPainter extends CustomPainter {
  const CrackPainter(this.damage);

  final double damage;

  @override
  void paint(Canvas canvas, Size size) {
    // A crack wanders and forks; a straight line reads as a scratch. The walk
    // is squashed vertically because a layer is far wider than it is tall, and
    // clipped rather than clamped so a fissure ends at the layer edge instead
    // of being pushed back inside it.
    canvas.clipRect(Offset.zero & size);

    final split = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < cracks.length; i++) {
      final opacity = (damage * 7 - i).clamp(0.0, 1.0);
      if (opacity <= 0.03) continue;

      final spec = cracks[i];
      final noise = Noise(i * 7919 + 13);
      final step = spec.length * size.width / 4;
      var angle = spec.turn * math.pi / 180;
      var point = Offset(spec.x * size.width, spec.y * size.height);
      final path = Path()..moveTo(point.dx, point.dy);
      for (var segment = 0; segment < 4; segment++) {
        angle += (noise.next() - 0.5) * 1.1;
        point += Offset(math.cos(angle) * step, math.sin(angle) * step * 0.5);
        path.lineTo(point.dx, point.dy);
      }

      lip.color = Color.fromRGBO(255, 255, 255, opacity * 0.2);
      split.color = Color.fromRGBO(0, 0, 0, opacity * 0.6);
      canvas.save();
      canvas.translate(0.9, 1);
      canvas.drawPath(path, lip);
      canvas.restore();
      canvas.drawPath(path, split);
    }
  }

  @override
  bool shouldRepaint(CrackPainter oldDelegate) => oldDelegate.damage != damage;
}
