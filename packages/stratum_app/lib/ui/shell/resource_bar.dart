import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../hud.dart';
import '../tokens.dart';
import '../resource_icon.dart';

import 'package:stratum_core/stratum_core.dart';

import 'round_badge.dart';
import 'round_gauge.dart';

class ResourceBar extends StatelessWidget {
  const ResourceBar({required this.game, required this.onTap, super.key});

  final Game game;

  /// The strip means ONE thing now: the whole of it opens financing. The
  /// warehouse moved to its own production tab when the strip stopped being
  /// its short form.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudTap(
      onTap: onTap,
      // The strip is a full-width surface over the scene: a rectangular
      // hover film across it reads as a glitch, the same lesson as the
      // overlays. The hand cursor alone says it opens something.
      wash: false,
      child: Container(
        height: AppMetrics.resourceBar,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF20B0C10), Color(0xB30B0C10), Color(0x000B0C10)],
          ),
        ),
        // Financing wears the strip now; the resources moved wholly into
        // the warehouse the chevron still opens. The strip was already the
        // warehouse's short form -- the round gauge is the financing
        // sheet's short form by the same rule.
        child: Row(
          children: [
            Expanded(
              // The badge SITS ON the gauge: the bar slides in from behind
              // the round it is filling, so the two read as one instrument
              // rather than a chip beside a stripe.
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Slides under the badge's straight edge only: shorter
                  // and the track's cells peek through the chamfer notches,
                  // which read as a glitch, not an overlap.
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: RoundGauge(
                      round: sim.financeRound,
                      target: sim.roundProgress,
                    ),
                  ),
                  // The reading with the currency's own face after it --
                  // composed here rather than through the bar's reading,
                  // which speaks text alone.
                  Positioned(
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, 0.8),
                          // Both numbers CUMULATIVE: the eye compares this
                          // pair against the lifetime turnover anyway, so
                          // the pair is written on that same scale.
                          child: Text(
                            '${sim.creditsEarned.value}'
                            ' / ${sim.roundFloor(sim.financeRound + 1)}',
                            style: AppText.display(
                              8.5,
                              weight: FontWeight.w700,
                              color: Palette.text,
                              height: 1,
                            ).copyWith(shadows: AppText.halo),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const ResourceIcon(ResourceId.credits, size: 11),
                      ],
                    ),
                  ),
                  RoundBadge(game: game, onTap: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
