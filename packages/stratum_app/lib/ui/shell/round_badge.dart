import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../hud.dart';
import '../tokens.dart';

/// The financing round, worn on the strip: the level the turnover bought,
/// and the dot when a tranche waits to be poured.
class RoundBadge extends StatelessWidget {
  const RoundBadge({required this.game, required this.onTap, super.key});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final free = sim.tranchesFree;
    return HudTap(
      onTap: onTap,
      corners: HudCorners.centred,
      cut: 6,
      child: HudPlate(
        cut: 6,
        fill: Palette.goldWell,
        edge: Palette.amber,
        padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
        // A floor under the width so the bar's fixed underlap always meets
        // the straight edge, whatever the round number's length.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Р${sim.financeRound}',
                style: AppText.display(
                  13,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                  height: 1.1,
                ),
              ),
              if (free > 0) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Palette.tech,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.page, width: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
