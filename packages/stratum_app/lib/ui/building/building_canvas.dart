import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../hud.dart';
import '../tokens.dart';
import 'building_node.dart';

/// The construction graph's canvas: pan and pinch over a field of placed
/// nodes, edges drawn underneath from each node's [BuildingNode.requires].
///
/// The first graph canvas of the game -- the trees will want the same
/// machinery when their nodes arrive, so nothing here knows what a node
/// MEANS: it draws positions, edges and selection, and the screen owns the
/// rest.
class BuildingCanvas extends StatefulWidget {
  const BuildingCanvas({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<BuildingCanvas> createState() => _BuildingCanvasState();
}

class _BuildingCanvasState extends State<BuildingCanvas> {
  final TransformationController _view = TransformationController();
  bool _framed = false;

  static const double _nodeW = 136;
  static const double _nodeH = 106;
  static const double _discR = 27;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  /// Opens centred on the foundation -- the heart of the web.
  void _frameOnRoot(Size viewport) {
    if (_framed) return;
    _framed = true;
    final root = buildingNodeOf('foundation').pos;
    _view.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - root.dx,
        viewport.height / 2 - root.dy,
        0,
        1,
      );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _frameOnRoot(constraints.biggest);
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _view,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(220),
            minScale: 0.55,
            maxScale: 1.8,
            child: SizedBox(
              width: buildingCanvasSize.width,
              height: buildingCanvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _FieldPainter()),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(selected: widget.selected),
                    ),
                  ),
                  for (final sector in buildingSectors)
                    Positioned(
                      left: sector.at.dx - 70,
                      top: sector.at.dy - 8,
                      width: 140,
                      child: IgnorePointer(
                        child: Text(
                          sector.label,
                          textAlign: TextAlign.center,
                          style: AppText.body(
                            9,
                            weight: FontWeight.w800,
                            letterSpacing: 3,
                            color: sector.colour.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  for (final node in buildingNodes)
                    Positioned(
                      // The DISC's centre sits on the node's position; the
                      // caption hangs below it.
                      left: node.pos.dx - _nodeW / 2,
                      top: node.pos.dy - _discR - 4,
                      width: _nodeW,
                      height: _nodeH,
                      child: _NodeFace(
                        node: node,
                        selected: widget.selected == node.id,
                        onTap: () => widget.onSelect(node.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One node of the web: a disc on the thread, its caption underneath.
/// The merge node carries a diamond glyph inside the disc.
class _NodeFace extends StatelessWidget {
  const _NodeFace({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final BuildingNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = node.locked ? node.colour.withValues(alpha: 0.45) : node.colour;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The HIT AREA is the disc itself: ClipOval clips hit-testing to
        // the circle, so a tap beside the rim or on the caption pans the
        // field instead of picking the node. The glow lives OUTSIDE the
        // clip, or the clip would shave it.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: node.colour.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : const [],
          ),
          child: ClipOval(
            child: HudTap(
              onTap: onTap,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? node.colour.withValues(alpha: 0.18)
                      : Palette.shell.withValues(
                          alpha: node.locked ? 0.5 : 0.95,
                        ),
                  border: Border.all(
                    color: selected ? node.colour : ink.withValues(alpha: 0.7),
                    width: selected ? 1.8 : 1.3,
                  ),
                ),
                child: Center(child: _core(ink)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  node.label,
                  style: AppText.display(
                    9,
                    weight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              if (node.unlock != null) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '⟐ ${node.unlock}',
                    style: AppText.display(
                      6.5,
                      color: node.locked
                          ? Palette.textFaint
                          : Palette.gold.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

extension on _NodeFace {
  /// The disc's core says the node's BREED at a glance: a solid core is
  /// a one-shot switch, one heavy ring is a few strong levels, three
  /// thin rings are a long ladder of small ones. The merge keeps its
  /// diamond, the root wears a core inside a rim.
  Widget _core(Color ink) {
    if (node.diamond) {
      return Text(
        '◇',
        style: AppText.display(16, weight: FontWeight.w700, color: ink),
      );
    }
    Widget ring(double d, double w) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: w),
      ),
    );
    Widget core(double d) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
    );
    return switch (node.kind) {
      NodeBreed.root => Stack(
        alignment: Alignment.center,
        children: [ring(20, 1.2), core(9)],
      ),
      NodeBreed.oneShot => core(12),
      NodeBreed.fewStrong => ring(16, 2.6),
      NodeBreed.manySmall => Stack(
        alignment: Alignment.center,
        children: [ring(20, 1.1), ring(13, 1.1), ring(6, 1.1)],
      ),
    };
  }
}

/// The field behind the web: each sector claims a tinted WEDGE from the
/// centre, boundary spokes divide the zones, ring orbits cross them, and
/// a rim arc in the sector colour underlines its caption.
class _FieldPainter extends CustomPainter {
  const _FieldPainter();

  static const double _rimR = 470;
  static const double _holeR = 64;

  @override
  void paint(Canvas canvas, Size size) {
    const centre = buildingCanvasCentre;
    final sorted = [...buildingSectors]
      ..sort((a, b) => a.bearing.compareTo(b.bearing));

    double edgeBefore(int i) {
      final prev = sorted[(i - 1 + sorted.length) % sorted.length].bearing;
      var a = sorted[i].bearing;
      var b = prev;
      if (b > a) b -= 2 * math.pi;
      return (a + b) / 2;
    }

    for (var i = 0; i < sorted.length; i++) {
      final sector = sorted[i];
      final from = edgeBefore(i);
      final to =
          edgeBefore((i + 1) % sorted.length) +
          ((i + 1) % sorted.length == 0 ? 2 * math.pi : 0);
      final sweep = (to - from) % (2 * math.pi) <= 0
          ? (to - from) % (2 * math.pi) + 2 * math.pi
          : (to - from) % (2 * math.pi);

      // The zone's wedge: a quiet wash of its own colour.
      final wedge = Path()
        ..moveTo(
          centre.dx + math.cos(from) * _holeR,
          centre.dy + math.sin(from) * _holeR,
        )
        ..arcTo(
          Rect.fromCircle(center: centre, radius: _rimR),
          from,
          sweep,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: centre, radius: _holeR),
          from + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(
        wedge,
        Paint()..color = sector.colour.withValues(alpha: 0.045),
      );

      // The rim arc under the caption: the sector's own colour, plain.
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: _rimR),
        from + 0.05,
        sweep - 0.1,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = sector.colour.withValues(alpha: 0.3),
      );

      // The boundary spoke opening this sector.
      final dir = Offset(math.cos(from), math.sin(from));
      canvas.drawLine(
        centre + dir * _holeR,
        centre + dir * _rimR,
        Paint()
          ..strokeWidth = 1.2
          ..color = Palette.line.withValues(alpha: 0.45),
      );
    }

    // Ring orbits over the wedges.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Palette.lineBar.withValues(alpha: 0.55);
    for (final r in const [190.0, 320.0, 450.0]) {
      canvas.drawCircle(centre, r, ring);
    }
    canvas.drawCircle(centre, _holeR, ring);
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => false;
}

/// Edges under the nodes, one per [BuildingNode.requires] entry: straight
/// vertical runs where the pair shares a column, an elbow otherwise.
/// Locked children hang on dashed lines.
class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.selected});

  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in buildingNodes) {
      for (final parentId in node.requires) {
        final parent = buildingNodeOf(parentId);
        // A web runs on straight radial threads: from edge to edge
        // along the line between the two centres.
        final line = node.pos - parent.pos;
        final unit = line / line.distance;
        final from = parent.pos + unit * 33;
        final to = node.pos - unit * 33;
        final lit =
            selected != null && (selected == node.id || selected == parentId);
        final ink = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lit ? 1.8 : 1.3
          ..color = node.colour.withValues(
            alpha: node.locked ? 0.25 : (lit ? 0.85 : 0.45),
          );
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
        if (node.locked) {
          canvas.drawPath(_dash(path), ink);
        } else {
          canvas.drawPath(path, ink);
        }
      }
    }
  }

  Path _dash(Path source) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(metric.extractPath(d, d + 5), Offset.zero);
        d += 10;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.selected != selected;
}
