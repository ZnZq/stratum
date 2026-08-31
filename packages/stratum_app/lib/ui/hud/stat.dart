import 'package:flutter/widgets.dart';

import '../stat.dart';
import '../tokens.dart';
import 'corners.dart';
import 'plate.dart';

/// A readout on a plate of its own, cut to the way it is read.
///
/// The house [Stat] does the type; this only frames it. So a HUD readout can
/// never drift from a plain one -- same heading size, same figure weight, same
/// unit slot -- and what it adds is the surface, not a second dialect.
class HudStat extends StatelessWidget {
  const HudStat({
    required this.label,
    this.value,
    this.child,
    this.align = CrossAxisAlignment.start,
    this.corners,
    this.accent = Palette.tech,
    this.colour = Palette.textDim,
    this.labelColour = Palette.tech,
    this.size,
    this.unit,
    // Tight at the sides on purpose: a plate that costs eleven pixels either
    // side takes them out of the heading, and the heading is the part that
    // cannot be abbreviated.
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 9),
    this.cut = 9,
    super.key,
  });

  final String label;
  final String? value;
  final Widget? child;
  final CrossAxisAlignment align;

  /// Overrides the cut the alignment would choose. For a grid of plates that
  /// has to read as one panel: only the block's outer corners are struck.
  final HudCorners? corners;

  /// The colour of the plate's edge.
  final Color accent;

  final Color colour;
  final Color labelColour;
  final double? size;
  final Widget? unit;
  final EdgeInsets padding;
  final double cut;

  @override
  Widget build(BuildContext context) {
    return HudPlate(
      corners: corners ?? HudCorners.of(align),
      cut: cut,
      fill: accent.withValues(alpha: 0.05),
      edge: accent.withValues(alpha: 0.28),
      padding: padding,
      child: Stat(
        label: label,
        value: value,
        align: align,
        colour: colour,
        labelColour: labelColour,
        size: size,
        unit: unit,
        child: child,
      ),
    );
  }
}
