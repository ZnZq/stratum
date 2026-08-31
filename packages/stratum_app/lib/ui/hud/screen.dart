import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'box.dart';
import 'corners.dart';

/// The frame a whole screen lives in.
///
/// The island every screen sat on was a rounded card with a shadow, which is
/// the one place the app still looked like an app. Same job -- clip the screen
/// and mark its edge -- with the console's outline: corners cut, a quiet edge,
/// and the four corners struck.
///
/// The screen is clipped to the chamfer, so a full-bleed scene (the borehole,
/// the arm's rock band) stops on the cut instead of running past it, and the
/// outline is painted OVER the content, because an opaque screen fills the
/// clip right to its edge.
class HudScreen extends StatelessWidget {
  const HudScreen({
    required this.child,
    this.cut = 18,
    this.edge = Palette.line,
    this.accent = Palette.tech,
    super.key,
  });

  final Widget child;
  final double cut;

  /// The quiet run along each side.
  final Color edge;

  /// The corners, in a colour of their own. Struck in the same grey as the
  /// sides they simply read as a slightly thicker line; the point of a
  /// bracket is that the eye finds the shape from it, and it cannot do that
  /// while the bracket is the same thing as the edge.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      corners: HudCorners.centred,
      cut: cut,
      edge: edge,
      bracket: accent.withValues(alpha: 0.7),
      bracketWidth: 1.8,
      bracketArm: 16,
      over: true,
      child: ClipPath(
        clipper: CornerClipper(HudCorners.centred, cut),
        child: child,
      ),
    );
  }
}
