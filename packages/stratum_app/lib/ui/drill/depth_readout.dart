import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../game_icons.dart';
import '../stat.dart';
import '../tokens.dart';

/// Depth, set into the top-left corner clear of the drill's channel.
class DepthReadout extends StatelessWidget {
  const DepthReadout({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    // No padding of its own: it is one element of the head band now, and the
    // band places it. The figure keeps its own size -- it is the headline of
    // the screen -- but it wears the same heading as every other readout.
    return Stat(
      label: 'глибина',
      icon: Ic.depth,
      shadows: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            sim.layer.value.big.toString(NumberStyle.integer),
            style: AppText.display(
              44,
              color: Palette.gold,
              height: 1,
              shadows: true,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'м',
            style: AppText.display(16, color: Palette.gold, shadows: true),
          ),
        ],
      ),
    );
  }
}
