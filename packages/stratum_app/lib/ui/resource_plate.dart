import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'tokens.dart';
import 'resource_icon.dart';

/// One resource, as a readout like any other: its name, a small fact about
/// it, and a figure beside its own icon.
///
/// The same plate serves the mine's loot table and the warehouse shelves,
/// because they are the same object seen twice -- what a strike can bring up,
/// and what the strikes have brought up. The small fact is the odds in one
/// place and the rate of income in the other; both qualify the lane rather
/// than the number, so both ride beside the name.
class ResourcePlate extends StatelessWidget {
  const ResourcePlate({
    required this.id,
    required this.amount,
    required this.width,
    this.aside,
    this.dim = false,
    this.shadows = false,
    this.plated = false,
    super.key,
  });

  final ResourceId id;

  /// The fact beside the name -- odds, or a rate. Null when there is none to
  /// tell: a guaranteed lane needs no odds, and an idle store no rate.
  final String? aside;

  final String amount;
  final double width;

  /// Nothing here yet, or not reachable yet. Drawn faint rather than hidden:
  /// the grid doubles as the map of what is still to come.
  final bool dim;

  /// Lifts the type off a busy background. The plates standing over the rock
  /// need it; the ones on a panel do not.
  final bool shadows;

  /// Seats the entry on the HUD plate ([HudStat]'s own surface). The mine's
  /// loot table stands on rock and stays bare; the warehouse grid stands on
  /// a panel and wears the instrument face like every readout there.
  final bool plated;

  /// What the icon is drawn at, and the height it is allowed to claim.
  static const double _iconSize = 23;
  static const double _iconSlot = 18;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    Widget entry = Stat(
      label: style.label,
      labelColour: style.colour,
      shadows: shadows,
      trailing: aside == null
          ? null
          : Text(
              aside!,
              style: AppText.display(
                8.5,
                weight: FontWeight.w600,
                color: Palette.textFaint,
                shadows: shadows,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.only(right: 2, top: 1),
        child: Row(
          children: [
            // Drawn larger than the room it claims. The row's height is
            // set by the icon box -- the figure beside it is shorter --
            // so growing the icon honestly would push every plate in the
            // grid taller. Bleeding a couple of pixels past the slot buys
            // the bigger silhouette for nothing.
            SizedBox(
              width: _iconSize,
              height: _iconSlot,
              child: OverflowBox(
                maxHeight: _iconSize,
                child: ResourceIcon(id, size: _iconSize),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(
                  11,
                  weight: FontWeight.w700,
                  color: dim ? Palette.textFaint : Palette.textDim,
                  shadows: shadows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (plated) {
      entry = HudPlate(
        cut: 9,
        fill: style.colour.withValues(alpha: 0.05),
        edge: style.colour.withValues(alpha: 0.28),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        child: entry,
      );
    }
    return SizedBox(
      width: width,
      child: Opacity(opacity: dim ? 0.45 : 1, child: entry),
    );
  }
}
