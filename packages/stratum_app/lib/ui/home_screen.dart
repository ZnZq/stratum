import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
import 'server_rack.dart';
import 'stat.dart';
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
  const HomeScreen({required this.game, super.key});

  final Game game;

  /// One size for every readout on this screen. The left column was set at 13
  /// and the right at 26, and the two sides did not read as a pair; the middle
  /// of them lets both columns hold the same weight.
  static const double _figure = 20;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ready = sim.pendingCollapses(now);
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
          Expanded(child: _panel(sim, fills, costs, ready)),
        ],
      ),
    );
  }

  Widget _panel(
    PrototypeSimulation sim,
    List<double> fills,
    List<String> costs,
    int ready,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppMetrics.navTotal + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two columns, not two rows: where the simulation stands on the
          // left, what it has produced on the right. The headline figures
          // then sit together instead of being split by a rule.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Two counts on one line, because they are the same kind
                    // of fact: what this save has CLOSED. Neither starts at
                    // one -- a fresh save has finished nothing.
                    Row(
                      children: [
                        Expanded(
                          child: Stat(
                            label: 'циклів',
                            value: '${sim.cycleNumber}',
                            size: _figure,
                            colour: Palette.steel,
                          ),
                        ),
                        Expanded(
                          child: Stat(
                            // Plural in the label, ordinal in the figure:
                            // this is the simulation you are IN, not a count
                            // of the ones behind you.
                            label: 'симуляцій',
                            value: '${sim.simulationNumber}',
                            size: _figure,
                            colour: Palette.steel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Stat(
                      label: 'глибина',
                      value: '${sim.layer.value} м',
                      size: _figure,
                      colour: Palette.steel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stat(
                      label: 'сирі дані',
                      unit: const _Unit(
                        size: 24,
                        child: ResourceIcon(ResourceId.rawData, size: 24),
                      ),
                      align: CrossAxisAlignment.end,
                      value: '${sim.rawData.value}',
                      size: _figure,
                      colour: Palette.tech,
                    ),
                    const SizedBox(height: 14),
                    Stat(
                      label: 'olap-куби',
                      unit: const _Unit(size: 24, child: CubesIcon(size: 24)),
                      labelColour: Palette.gold,
                      align: CrossAxisAlignment.end,
                      value: '${sim.dataWallet.value}',
                      size: _figure,
                      colour: Palette.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // The two acts, in the order they are reached: banking is always
          // available, oversaturation is the wall.
          _Act(
            label: 'перезапуск',
            colour: Palette.gold,
            headline: '+${sim.bankableData.value}',
            note: 'з цієї симуляції · в olap-куби',
          ),
          const SizedBox(height: 9),
          const _Rule(),
          const SizedBox(height: 9),
          // The wall itself instead of a bar: five racks say how full each
          // one is AND what each costs, which a single bar never could.
          _Act(
            label: 'колапс',
            colour: ready > 0 ? Palette.alarm : Palette.quantonium,
            headline: ready > 0
                ? 'готово $ready з '
                      '${PrototypeSimulation.maxPendingCollapses} · +$ready очко'
                : 'дрейф −3%/добу',
            note: ready >= PrototypeSimulation.maxPendingCollapses
                ? 'стіна повна · далі складати нікуди'
                : 'сервер = один колапс і один цикл',
            // No height given: a rack knows how tall it has to be to still
            // look like a rack, and says so.
            below: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var r = 0; r < fills.length; r++) ...[
                  Expanded(
                    child: ServerRack(fill: fills[r], cost: costs[r], phase: r),
                  ),
                  if (r < fills.length - 1) const SizedBox(width: 10),
                ],
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

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Palette.lineBar));
}

/// One of the two things this screen is for.
///
/// Carries its own preview rather than a button for now: the acts are not
/// built, and a control that does nothing is worse than a number that is
/// honest about waiting.
class _Act extends StatelessWidget {
  const _Act({
    required this.label,
    required this.colour,
    required this.headline,
    required this.note,
    this.below,
  });

  final String label;
  final Color colour;
  final String headline;
  final String note;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Stat(
      label: label,
      labelColour: colour,
      trailing: const _Soon(),
      value: headline,
      size: 15,
      colour: colour,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (below case final below?) ...[const SizedBox(height: 5), below],
          const SizedBox(height: 4),
          Text(note, style: AppText.display(9.5, color: Palette.textFaint)),
        ],
      ),
    );
  }
}

/// The tag on an act that reads out but does not act yet.
class _Soon extends StatelessWidget {
  const _Soon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
      decoration: BoxDecoration(
        color: Palette.bar,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Text('згодом', style: AppText.body(8.5, color: Palette.textFaint)),
    );
  }
}
