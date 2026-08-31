import 'package:flutter/widgets.dart';

import '../resource_style.dart';

import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';

import 'noise.dart';

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
