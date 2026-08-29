import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
import 'hud.dart';
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
                  lamp: Palette.gold,
                  label: 'перезапуск',
                  colour: Palette.gold,
                  figure: '+${sim.bankableData.value}',
                  unit: const _Unit(size: 22, child: CubesIcon(size: 22)),
                  note: 'згортає симуляцію · глибина, ресурси і бури з нею',
                  action: 'ЗГОРНУТИ',
                  onAct: null,
                ),
                const SizedBox(height: 15),
                _Act(
                  lamp: ready > 0 ? Palette.alarm : Palette.tech,
                  label: 'колапс',
                  colour: ready > 0 ? Palette.alarm : Palette.quantonium,
                  figure: '$ready / ${PrototypeSimulation.maxPendingCollapses}',
                  note: ready >= PrototypeSimulation.maxPendingCollapses
                      ? 'стіна повна · далі складати нікуди'
                      : 'сервер = очко колапсу і цикл · поріг тане 3% за добу',
                  action: ready > 0 ? 'ЗАБРАТИ $ready' : 'ЗАБРАТИ',
                  onAct: null,
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
    required this.lamp,
    required this.label,
    required this.colour,
    required this.figure,
    required this.note,
    required this.action,
    required this.onAct,
    this.unit,
    this.body,
  });

  final Color lamp;
  final String label;
  final Color colour;
  final String figure;
  final String note;
  final String action;
  final VoidCallback? onAct;
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
            HudLamp(colour: lamp),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                note,
                style: AppText.body(9, color: Palette.textFaint),
              ),
            ),
            const SizedBox(width: 12),
            HudButton(label: action, accent: colour, onTap: onAct),
          ],
        ),
      ],
    );
  }
}
