import 'package:flutter/widgets.dart';

import 'corners.dart';

/// The one surface every HUD part is cut from.
///
/// Corners, sides and corner strikes are three independent choices, and every
/// panel in the game turns out to be a combination of them: a plate is all
/// sides and no strikes, a menu cell is two sides, a bracket frame is no
/// sides and long strikes, a sheet is every side with short ones. Holding
/// them apart is what stopped this file from growing a painter per shape.
class HudBox extends StatelessWidget {
  const HudBox({
    required this.child,
    this.corners = HudCorners.centred,
    this.sides = HudSides.all,
    this.cut = 8,
    this.fill,
    this.edge,
    this.edgeWidth = 1,
    this.bracket,
    this.bracketWidth = 1.6,
    this.bracketArm = 0,
    this.brackets = HudCorners.centred,
    this.padding = EdgeInsets.zero,
    this.over = false,
    super.key,
  });

  final Widget child;
  final HudCorners corners;
  final HudSides sides;
  final double cut;

  /// The body. Null leaves whatever is behind showing through.
  final Color? fill;

  /// The thin outline, drawn along the enabled [sides] and across every cut.
  final Color? edge;
  final double edgeWidth;

  /// The heavy strike at each corner, drawn over the edge. The eye takes a
  /// shape from its corners, which is what lets the rest of an outline stay
  /// quiet -- or disappear entirely.
  final Color? bracket;
  final double bracketWidth;

  /// How far a strike runs along each side it meets. Zero marks the cut
  /// alone; a long arm makes the corner brackets of a frame.
  final double bracketArm;

  /// WHICH corners are struck. A fourth axis, held apart from [corners] for
  /// the same reason the first three are: which corners are cut and which are
  /// hit are different questions, and a shape that can only answer them
  /// together cannot be a plinth, a header rule or an open bracket.
  final HudCorners brackets;

  final EdgeInsets padding;

  /// Draws the outline OVER the child instead of behind it. For a box whose
  /// content fills it to the edge -- a screen, a clipped panel -- where an
  /// outline underneath is simply covered up.
  final bool over;

  @override
  Widget build(BuildContext context) {
    final painter = _BoxPainter(
      corners: corners,
      sides: sides,
      cut: cut,
      fill: fill,
      edge: edge,
      edgeWidth: edgeWidth,
      bracket: bracket,
      bracketWidth: bracketWidth,
      bracketArm: bracketArm,
      brackets: brackets,
    );
    return CustomPaint(
      painter: over ? null : painter,
      foregroundPainter: over ? painter : null,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter({
    required this.corners,
    required this.sides,
    required this.cut,
    required this.fill,
    required this.edge,
    required this.edgeWidth,
    required this.bracket,
    required this.bracketWidth,
    required this.bracketArm,
    required this.brackets,
  });

  final HudCorners corners;
  final HudSides sides;
  final double cut;
  final Color? fill;
  final Color? edge;
  final double edgeWidth;
  final Color? bracket;
  final double bracketWidth;
  final double bracketArm;
  final HudCorners brackets;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = cut > h / 2 ? h / 2 : cut;

    if (fill case final fill?) {
      canvas.drawPath(corners.path(size, cut), Paint()..color = fill);
    }

    if (edge case final edge?) {
      final ink = Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..strokeCap = StrokeCap.square;
      final line = Path();
      if (sides.top) {
        line
          ..moveTo(corners.topLeft ? c : 0, 0)
          ..lineTo(corners.topRight ? w - c : w, 0);
      }
      if (sides.right) {
        line
          ..moveTo(w, corners.topRight ? c : 0)
          ..lineTo(w, corners.bottomRight ? h - c : h);
      }
      if (sides.bottom) {
        line
          ..moveTo(corners.bottomRight ? w - c : w, h)
          ..lineTo(corners.bottomLeft ? c : 0, h);
      }
      if (sides.left) {
        line
          ..moveTo(0, corners.bottomLeft ? h - c : h)
          ..lineTo(0, corners.topLeft ? c : 0);
      }
      // A cut belongs to the outline whenever either side it joins is drawn:
      // otherwise a menu cell would show two floating verticals.
      if (corners.topLeft && (sides.top || sides.left)) {
        line
          ..moveTo(c, 0)
          ..lineTo(0, c);
      }
      if (corners.topRight && (sides.top || sides.right)) {
        line
          ..moveTo(w - c, 0)
          ..lineTo(w, c);
      }
      if (corners.bottomRight && (sides.bottom || sides.right)) {
        line
          ..moveTo(w, h - c)
          ..lineTo(w - c, h);
      }
      if (corners.bottomLeft && (sides.bottom || sides.left)) {
        line
          ..moveTo(c, h)
          ..lineTo(0, h - c);
      }
      canvas.drawPath(line, ink);
    }

    if (bracket case final bracket?) {
      final arm = bracketArm;
      final ink = Paint()
        ..color = bracket
        ..style = PaintingStyle.stroke
        ..strokeWidth = bracketWidth
        ..strokeCap = StrokeCap.square;
      final strike = Path();

      void corner(
        bool struck,
        bool isCut,
        Offset alongTop,
        Offset cutStart,
        Offset cutEnd,
        Offset alongSide,
        Offset square,
      ) {
        if (!struck) return;
        if (isCut) {
          strike
            ..moveTo(alongTop.dx, alongTop.dy)
            ..lineTo(cutStart.dx, cutStart.dy)
            ..lineTo(cutEnd.dx, cutEnd.dy)
            ..lineTo(alongSide.dx, alongSide.dy);
        } else {
          strike
            ..moveTo(alongTop.dx, alongTop.dy)
            ..lineTo(square.dx, square.dy)
            ..lineTo(alongSide.dx, alongSide.dy);
        }
      }

      corner(
        brackets.topLeft,
        corners.topLeft,
        Offset(c + arm, 0),
        Offset(c, 0),
        Offset(0, c),
        Offset(0, c + arm),
        Offset.zero,
      );
      corner(
        brackets.topRight,
        corners.topRight,
        Offset(w - c - arm, 0),
        Offset(w - c, 0),
        Offset(w, c),
        Offset(w, c + arm),
        Offset(w, 0),
      );
      corner(
        brackets.bottomRight,
        corners.bottomRight,
        Offset(w - c - arm, h),
        Offset(w - c, h),
        Offset(w, h - c),
        Offset(w, h - c - arm),
        Offset(w, h),
      );
      corner(
        brackets.bottomLeft,
        corners.bottomLeft,
        Offset(c + arm, h),
        Offset(c, h),
        Offset(0, h - c),
        Offset(0, h - c - arm),
        Offset(0, h),
      );
      canvas.drawPath(strike, ink);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.corners != corners ||
      old.sides.top != sides.top ||
      old.sides.right != sides.right ||
      old.sides.bottom != sides.bottom ||
      old.sides.left != sides.left ||
      old.cut != cut ||
      old.fill != fill ||
      old.edge != edge ||
      old.bracket != bracket ||
      old.bracketArm != bracketArm ||
      old.brackets != brackets;
}
