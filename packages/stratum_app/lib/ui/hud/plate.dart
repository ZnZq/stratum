import 'package:flutter/widgets.dart';

import 'box.dart';
import 'corners.dart';

/// A chamfered surface with nothing to press.
///
/// The panel equivalent of a rounded Container: a fill, an optional edge, and
/// corners taken off to whatever pattern the content asks for.
class HudPlate extends StatelessWidget {
  const HudPlate({
    required this.child,
    this.corners = HudCorners.centred,
    this.fill,
    this.edge,
    this.cut = 7,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final HudCorners corners;
  final Color? fill;
  final Color? edge;
  final double cut;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      corners: corners,
      cut: cut,
      fill: fill,
      edge: edge,
      padding: padding,
      child: child,
    );
  }
}
