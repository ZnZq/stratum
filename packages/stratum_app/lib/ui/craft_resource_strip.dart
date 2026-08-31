import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'tokens.dart';

/// The bench's till: credits and the raw inputs at the top of the craft
/// screen, icon and figure only, with the warehouse a modal away -- checking
/// stock must never cost a navigation.
class CraftResourceStrip extends StatelessWidget {
  const CraftResourceStrip({
    required this.game,
    required this.onWarehouse,
    super.key,
  });

  final Game game;
  final VoidCallback onWarehouse;

  static const List<ResourceId> _raw = [
    ResourceId.regolith,
    ResourceId.cuprite,
    ResourceId.ferrite,
    ResourceId.silicite,
    ResourceId.crystals,
  ];

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudPlate(
      cut: 7,
      fill: Palette.shell.withValues(alpha: 0.7),
      edge: Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 7),
      child: Row(
        children: [
          ResourceIcon(ResourceId.credits, size: 12),
          const SizedBox(width: 4),
          Text(
            '${sim.stock.amount(ResourceId.credits)}',
            style: AppText.display(
              10.5,
              weight: FontWeight.w700,
              color: Palette.credit,
            ),
          ),
          const SizedBox(width: 9),
          const SizedBox(
            width: 1,
            height: 16,
            child: ColoredBox(color: Palette.lineBar),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (final id in _raw) ...[
                    if (id != _raw.first) const SizedBox(width: 8),
                    ResourceIcon(id, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      '${sim.stock.amount(id)}',
                      style: AppText.display(
                        9.5,
                        weight: FontWeight.w600,
                        color: sim.stock.amount(id).isZero
                            ? Palette.amber
                            : Palette.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          HudButton(
            onTap: onWarehouse,
            accent: Palette.textMuted,
            padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
            child: Text(
              'СКЛАД',
              style: AppText.body(
                8,
                weight: FontWeight.w800,
                letterSpacing: 1,
                color: Palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
