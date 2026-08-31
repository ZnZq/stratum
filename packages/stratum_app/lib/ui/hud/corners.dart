import 'package:flutter/widgets.dart';

import 'box.dart';

class HudCorners {
  const HudCorners({
    this.topLeft = false,
    this.topRight = false,
    this.bottomRight = false,
    this.bottomLeft = false,
  });

  final bool topLeft;
  final bool topRight;
  final bool bottomRight;
  final bool bottomLeft;

  static const HudCorners none = HudCorners();
  static const HudCorners leading = HudCorners(
    topLeft: true,
    bottomRight: true,
  );
  static const HudCorners trailing = HudCorners(
    topRight: true,
    bottomLeft: true,
  );
  static const HudCorners centred = HudCorners(
    topLeft: true,
    topRight: true,
    bottomRight: true,
    bottomLeft: true,
  );

  static HudCorners of(CrossAxisAlignment align) => switch (align) {
    CrossAxisAlignment.end => trailing,
    CrossAxisAlignment.center => centred,
    _ => leading,
  };

  Path path(Size size, double cut) {
    final w = size.width;
    final h = size.height;
    final c = cut > h / 2 ? h / 2 : cut;
    final path = Path()..moveTo(topLeft ? c : 0, 0);
    if (topRight) {
      path
        ..lineTo(w - c, 0)
        ..lineTo(w, c);
    } else {
      path.lineTo(w, 0);
    }
    if (bottomRight) {
      path
        ..lineTo(w, h - c)
        ..lineTo(w - c, h);
    } else {
      path.lineTo(w, h);
    }
    if (bottomLeft) {
      path
        ..lineTo(c, h)
        ..lineTo(0, h - c);
    } else {
      path.lineTo(0, h);
    }
    if (topLeft) path.lineTo(0, c);
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is HudCorners &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}

/// Which straight runs of the outline are drawn.
///
/// Separate from the corners because they are separate decisions: a menu cell
/// is cut on all four and drawn on two, and a bracket frame is cut on none
/// and drawn on none at all.
class HudSides {
  const HudSides({
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.left = true,
  });

  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  static const HudSides all = HudSides();
  static const HudSides none = HudSides(
    top: false,
    right: false,
    bottom: false,
    left: false,
  );

  /// Left and right only: the run reads as one strip rather than a line of
  /// boxes, which is what a menu wants.
  static const HudSides upright = HudSides(top: false, bottom: false);
}

/// Clips to the same outline a [HudBox] draws, so content and frame agree.
class CornerClipper extends CustomClipper<Path> {
  const CornerClipper(this.corners, this.cut);

  final HudCorners corners;
  final double cut;

  @override
  Path getClip(Size size) => corners.path(size, cut);

  @override
  bool shouldReclip(CornerClipper old) =>
      old.corners != corners || old.cut != cut;
}
