import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'box.dart';
import 'corners.dart';

/// Corner brackets instead of a frame.
///
/// The game's rule is one surface, no boxes inside boxes -- but a console
/// still needs to say where it begins. Four short Ls mark the corners and
/// leave the sides open, so the block is bracketed without being boxed.
class HudBrackets extends StatelessWidget {
  const HudBrackets({
    required this.child,
    this.colour = Palette.tech,
    this.struck = HudCorners.centred,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    super.key,
  });

  final Widget child;
  final Color colour;

  /// Which corners are marked. Four is a console; the bottom pair alone is a
  /// plinth the block is seated on, which is what a block INSIDE a framed
  /// screen wants -- four would be a second frame around the first.
  final HudCorners struck;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      corners: HudCorners.none,
      sides: HudSides.none,
      bracket: colour.withValues(alpha: 0.34),
      brackets: struck,
      bracketWidth: 1.2,
      bracketArm: 13,
      padding: padding,
      child: child,
    );
  }
}
