import 'package:flutter/widgets.dart';

import '../game.dart';
import 'hud.dart';
import 'tokens.dart';

/// What a blow is worth right now: the power it lands with, and the band of
/// regolith it comes back with.
///
/// The two ends of that band are what the bit and the drive buy, so the
/// screen states them before it offers to sell anything.
class BlowSummary extends StatelessWidget {
  const BlowSummary({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    // Cut as ONE panel, not two plates: only the pair's outer corners are
    // struck, so the seam between them stays square.
    return Row(
      children: [
        Expanded(
          child: HudStat(
            label: 'сила удару',
            corners: const HudCorners(topLeft: true, bottomLeft: true),
            accent: Palette.gold,
            // One Text.rich, one line: the share sits BESIDE the figure
            // (owner). Three decimals, so the sum visibly equals the
            // drive's own bonus plus the 0.02% floor every blow carries
            // -- two decimals rounded it into a number the upgrade
            // track never mentions.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${sim.strikePower}',
                    style: AppText.display(
                      13,
                      weight: FontWeight.w700,
                      color: Palette.gold,
                    ),
                  ),
                  TextSpan(
                    text:
                        '  +${(sim.pierceShare * 100).toStringAsFixed(3)}% шару',
                    style: AppText.display(8, color: Palette.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HudStat(
            label: 'реголіт за удар',
            align: CrossAxisAlignment.end,
            corners: const HudCorners(topRight: true, bottomRight: true),
            value: '${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}',
            size: 13,
            accent: Palette.ore,
            colour: Palette.ore,
            labelColour: Palette.ore,
          ),
        ),
      ],
    );
  }
}
