import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
import 'hud.dart';
import 'server_rack.dart';
import 'tree_sheet.dart';
import 'tokens.dart';

/// The Data Centre: the machine the digging is FOR.
///
/// Shown when the player steps out of every screen. The islands are windows
/// down a hole; this is the surface the hole serves -- substrate comes up the
/// shaft, the racks compile it into corpus, and the two acts that spend it
/// live here. So the shell is not "the game with nothing open" any more; it
/// is a place with its own job.
///
/// One surface, like the rest of the game: the racks run edge to edge, the
/// readouts fade in over their floor, and nothing below is boxed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.game, required this.onTree, super.key});

  final Game game;

  /// Opening a tree. A sheet over this screen rather than a screen of its
  /// own: what a tree spends is banked one line above it.
  final ValueChanged<TreeKind> onTree;

  /// One size for every readout on this screen. The left column was set at 13
  /// and the right at 26, and the two sides did not read as a pair; the middle
  /// of them lets both columns hold the same weight.
  static const double _figure = 20;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ready = sim.pendingCollapses(now);
    final open = sim.unlockedServers;
    const racks = PrototypeSimulation.maxPendingCollapses;
    final fills = [for (var r = 0; r < racks; r++) sim.rackFill(r, now)];
    final costs = [
      for (var r = 0; r < racks; r++) '${sim.collapseCost(r, now)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppMetrics.resourceBar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 26),
          Center(
            child: Text(
              'STRATUM',
              style: AppText.display(
                22,
                weight: FontWeight.w700,
                color: const Color(0x667FD9C4),
                letterSpacing: 11,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Expanded(child: _panel(sim, fills, costs, ready, open)),
        ],
      ),
    );
  }

  Widget _panel(
    PrototypeSimulation sim,
    List<double> fills,
    List<String> costs,
    int ready,
    int open,
  ) {
    return Padding(
      // Clears the section bar, NOT the strip above it. The strip keeps its
      // height even when empty so panels anchored at navTotal do not float --
      // but on the shell it holds nothing, and reserving 44 px for nothing is
      // 44 px the console could have.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppMetrics.navBar + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Five plates cut as ONE panel: only the block's outer corners
          // are struck, and every seam between plates stays square. Each
          // plate cut to its own reading looked like five separate cards
          // stacked, which is the opposite of what the group is.
          Row(
            children: [
              Expanded(
                child: HudStat(
                  // A count, not an ordinal: a fresh save has closed none.
                  label: 'циклів',
                  corners: const HudCorners(topLeft: true),
                  value: '${sim.cycleNumber}',
                  size: _figure,
                  accent: Palette.steel,
                  colour: Palette.steel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudStat(
                  label: 'сирі дані',
                  align: CrossAxisAlignment.end,
                  corners: const HudCorners(topRight: true),
                  value: '${sim.rawData.value}',
                  size: _figure,
                  accent: Palette.tech,
                  colour: Palette.tech,
                  unit: const _Unit(
                    size: 24,
                    child: ResourceIcon(ResourceId.rawData, size: 24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: HudStat(
                  // Plural in the label, ordinal in the figure: this is the
                  // simulation you are IN, not a count of the ones behind.
                  label: 'симуляцій',
                  corners: HudCorners.none,
                  value: '${sim.simulationNumber}',
                  size: _figure,
                  accent: Palette.steel,
                  colour: Palette.steel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudStat(
                  label: 'olap-куби',
                  align: CrossAxisAlignment.end,
                  corners: HudCorners.none,
                  value: '${sim.dataWallet.value}',
                  size: _figure,
                  accent: Palette.gold,
                  colour: Palette.gold,
                  labelColour: Palette.gold,
                  unit: const _Unit(size: 24, child: CubesIcon(size: 24)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HudStat(
            label: 'глибина',
            align: CrossAxisAlignment.center,
            corners: const HudCorners(bottomLeft: true, bottomRight: true),
            value: '${sim.layer.value} м',
            size: _figure,
            accent: Palette.steel,
            colour: Palette.steel,
          ),

          const Spacer(),

          // The console: two acts, bracketed rather than boxed. They were two
          // readouts with a rule between them and a "later" chip on each --
          // which made the most important controls on the screen look like
          // labels that happened to be disabled.
          HudBrackets(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Act(
                  label: 'перезапуск',
                  colour: Palette.gold,
                  figure: '+${sim.bankableData.value}',
                  unit: const _Unit(size: 22, child: CubesIcon(size: 22)),
                  // What the act does, and where what it pays is spent.
                  action: 'ЗГОРНУТИ',
                  onAct: null,
                  spend: 'ДЕРЕВО СИМУЛЯЦІЇ',
                  onSpend: () => onTree(TreeKind.simulation),
                ),
                const SizedBox(height: 13),
                _Act(
                  label: 'колапс',
                  colour: ready > 0 ? Palette.alarm : Palette.quantonium,
                  // Against what is OPEN, not against the wall's ceiling:
                  // "0 / 5" would promise capacity the player has not bought.
                  figure: '$ready / $open',
                  action: ready > 0 ? 'ЗАБРАТИ $ready' : 'ЗАБРАТИ',
                  onAct: null,
                  // Not a second "tree": the simulation tree tunes what this
                  // cycle's runs get, collapse points rewrite what every
                  // future cycle runs ON. A level below, so a different word.
                  spend: 'ПРОШИВКА',
                  onSpend: () => onTree(TreeKind.firmware),
                  // No height given: a rack knows how tall it has to be to
                  // still look like a rack, and says so.
                  body: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var r = 0; r < fills.length; r++) ...[
                        Expanded(
                          child: ServerRack(
                            fill: fills[r],
                            cost: costs[r],
                            phase: r,
                            locked: r >= open,
                          ),
                        ),
                        if (r < fills.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The join between the racks and the readouts.
/// A specimen beside a figure, drawn LARGER than the room it claims.
///
/// The row's height is set by the figure, so a unit that asked for its true
/// size honestly would push the whole readout taller -- and these two sit
/// opposite three that have no unit at all, which is exactly where a few
/// pixels of difference show. Bleeding past the slot buys the bigger
/// silhouette for nothing.
class _Unit extends StatelessWidget {
  const _Unit({required this.size, required this.child});

  /// How big the face is drawn. Per specimen rather than shared: the two
  /// drawings fill their box differently -- the cube's mass reaches almost
  /// every edge, the substrate's sits inside its loose cells -- so equal
  /// numbers do not read as equal weight.
  final double size;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: HomeScreen._figure,
      child: OverflowBox(maxWidth: size, maxHeight: size, child: child),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.label,
    required this.colour,
    required this.figure,
    required this.action,
    required this.onAct,
    required this.spend,
    required this.onSpend,
    this.unit,
    this.body,
  });

  final String label;
  final Color colour;
  final String figure;

  /// The act itself, and the place its payout is spent. Side by side, because
  /// they are the two halves of one decision: end this, then go spend it.
  final String action;
  final VoidCallback? onAct;
  final String spend;
  final VoidCallback? onSpend;

  final Widget? unit;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The lamp wears the line's own colour, not the capacity
            // language of the racks below it: within one console line the
            // lamp, the name and the figure have to say the same thing.
            HudLamp(colour: colour),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: AppText.body(
                9,
                weight: FontWeight.w800,
                color: colour,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: colour.withValues(alpha: 0.16)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              figure,
              style: AppText.display(
                18,
                weight: FontWeight.w700,
                color: colour,
                height: 1,
              ),
            ),
            if (unit case final unit?) ...[const SizedBox(width: 6), unit],
          ],
        ),
        if (body case final body?) ...[const SizedBox(height: 11), body],
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: HudButton(
                onTap: onAct,
                label: action,
                accent: colour,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: HudButton(
                onTap: onSpend,
                label: spend,
                accent: Palette.tech,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
