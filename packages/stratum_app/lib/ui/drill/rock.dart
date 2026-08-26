/// The borehole wall: the layers themselves, their texture and their cracks.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../resource_style.dart';
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
                child: CustomPaint(painter: CrackPainter(damage, layer: layer)),
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

    // The ore that layer actually carries, as coloured specks: each
    // obtainable resource seeds flecks in proportion to its drop chance, so
    // a glance at the rock says what digging here pays before the loot table
    // is ever opened.
    void stones(
      Color colour, {
      required double radius,
      required double saturation,
      required int count,
    }) {
      final fill = Paint()..color = colour.withValues(alpha: saturation);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x40000000);
      final glint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.35 * saturation);

      final inset = radius + 3;
      for (var i = 0; i < count; i++) {
        final centre = Offset(
          inset + noise.next() * (size.width - inset * 2),
          inset + noise.next() * (size.height - inset * 2),
        );

        // The same irregular-polygon cut as the barren clasts, so the ore
        // stones look embedded in the rock rather than stickered onto it.
        final path = Path();
        const sides = 5;
        for (var v = 0; v < sides; v++) {
          final angle = v / sides * math.pi * 2 + noise.next() * 0.7;
          final reach = radius * (0.6 + noise.next() * 0.5);
          final point =
              centre +
              Offset(math.cos(angle) * reach, math.sin(angle) * reach * 0.7);
          if (v == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();

        canvas.drawPath(path, fill);
        canvas.drawPath(path, rim);
        canvas.drawCircle(
          centre + Offset(-radius * 0.25, -radius * 0.3),
          radius * 0.22,
          glint,
        );
      }
    }

    if (thick) {
      // A thick layer's break pays every resource, guaranteed and tripled,
      // so its stones ignore the odds: each resource sits in it as a few
      // large rich pieces. A few -- the promise reads from a handful, and a
      // tile solid with stones would just be noise.
      // Per resource, and denser than any ordinary layer's best odds: the
      // ceiling of the chance-driven look is ~6 stones, so the guaranteed
      // triple payout starts above it and reads unmistakably richer.
      final count = (size.width * size.height / 5000).round().clamp(7, 14);
      for (final (colour, _) in _speckTable(layer)) {
        stones(colour, radius: 4.2, saturation: 0.85, count: count);
      }
    } else {
      // Richer odds read as richer rock: a likelier resource sits in the
      // layer as bigger, brighter and more numerous stones, a long shot as
      // a few faint pebbles.
      for (final (colour, chance) in _speckTable(layer)) {
        stones(
          colour,
          radius: 2.0 + chance * 6.5,
          saturation: (0.35 + chance * 1.2).clamp(0.0, 0.9).toDouble(),
          count: (size.width * size.height / 2000 * chance * 2.2).round().clamp(
            1,
            40,
          ),
        );
      }
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

  /// Which resources speck this layer, and how thickly.
  ///
  /// Chances come straight from the loot table, so the rock never advertises
  /// odds the strike would not honour.
  static List<(Color, double)> _speckTable(int layer) => [
    for (final row in PrototypeSimulation.oreTable)
      if (layer >= row.unlockAt) (resourceStyles[row.id]!.colour, row.chance),
    (
      resourceStyles[ResourceId.crystals]!.colour,
      PrototypeSimulation.crystalChanceAt(layer),
    ),
    (
      resourceStyles[ResourceId.quantonium]!.colour,
      PrototypeSimulation.strikeQuantoniumChance,
    ),
  ];

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
