import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'box.dart';
import 'corners.dart';
import 'tap.dart';

/// A navigation cell: the button's chamfer with its top and bottom opened.
///
/// A menu is a run of slots, not a row of separate controls. Closing every
/// cell on all four sides drew four boxes; leaving the horizontal edges open
/// turns the same outline into two angled brackets per slot, and the row
/// reads as one strip of a panel with the selected slot lit.
class HudMenu extends StatelessWidget {
  const HudMenu({
    required this.child,
    required this.onTap,
    this.active = false,
    this.accent = Palette.gold,
    this.cut = 8,
    this.padding = const EdgeInsets.symmetric(vertical: 5),
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool active;
  final Color accent;

  /// How much of each corner is taken off. Smaller cells want a smaller cut,
  /// or the chamfer eats the slot.
  final double cut;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onTap,
      corners: HudCorners.centred,
      cut: cut,
      child: HudBox(
        corners: HudCorners.centred,
        // Horizontals open: the run reads as one strip of a panel rather
        // than a line of separate boxes.
        sides: HudSides.upright,
        cut: cut,
        fill: active ? accent.withValues(alpha: 0.14) : null,
        edge: active ? accent.withValues(alpha: 0.85) : Palette.lineBar,
        edgeWidth: active ? 1.4 : 1,
        padding: padding,
        child: child,
      ),
    );
  }
}
