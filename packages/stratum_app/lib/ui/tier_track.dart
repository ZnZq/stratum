import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'tokens.dart';

/// The compression ladder in the board's own language: chosen cells lit,
/// bought ones banked, the rest of the track dark -- one glance says
/// level, ceiling and headroom. The line's board and the picker draw the
/// same ladder.
class TierTrack extends StatelessWidget {
  const TierTrack({required this.tier, required this.cap, super.key});

  final int tier;
  final int cap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < craftTierCapMax; i++) ...[
          if (i > 0) const SizedBox(width: 1.5),
          Expanded(
            child: SizedBox(
              height: 4.5,
              child: ColoredBox(
                color: i < tier
                    ? Palette.gold
                    : i < cap
                    ? Palette.goldWell
                    : Palette.card,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
