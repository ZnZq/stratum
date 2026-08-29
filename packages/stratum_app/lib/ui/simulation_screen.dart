import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
import 'hud.dart';
import 'navigation.dart';
import 'server_rack.dart';
import 'tokens.dart';

/// The Data Centre: the machine the digging is FOR.
///
/// Everything a simulation ENDS with. The other screens are windows down a
/// hole; this one looks at the machine the hole feeds -- substrate comes up
/// the shaft, the racks compile it into cubes, and the two acts that spend
/// them live here with the wall that says how close the next one is.
///
/// One surface, like the rest of the game: the racks run edge to edge, the
/// readouts sit over their floor, and nothing below is boxed.
class SimulationScreen extends StatelessWidget {
  const SimulationScreen({required this.game, required this.onOpen, super.key});

  final Game game;

  /// Going to a sibling tab. The acts pay into the trees next door, so each
  /// one carries the door to where its payout is spent.
  final ValueChanged<GameScreen> onOpen;

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
    // Only the rack being filled has a price worth reading: the ones behind
    // are paid for and the ones ahead are locked.
    final next = ready < open ? '${sim.collapseCost(ready, now)}' : null;
    return _panel(sim, fills, next, '${sim.walletEarned}', now, ready, open);
  }

  Widget _panel(
    PrototypeSimulation sim,
    List<double> fills,
    String? next,
    String held,
    int now,
    int ready,
    int open,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
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
            // Only the top pair. The screen's own frame already marks the
            // bottom two corners a few pixels below, and two sets of Ls in
            // one corner read as a box inside a box -- which is the one
            // thing this layout is not. Open at the foot, the console runs
            // out into the screen's floor instead of walling itself off.
            struck: const HudCorners(topLeft: true, topRight: true),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Act(
                  label: 'перезапуск',
                  colour: Palette.gold,
                  figure: '+${sim.bankableData.value}',
                  unit: const _Unit(size: 22, child: CubesIcon(size: 22)),
                  // Named for what it PAYS, not for what it ends: the run
                  // compiles into cubes, which is the game's own word for it
                  // (compileRate, rawPerCube).
                  action: 'СКОМПІЛЮВАТИ',
                  onAct: null,
                ),
                const SizedBox(height: 13),
                _Act(
                  label: 'перевантаження',
                  colour: ready > 0 ? Palette.alarm : Palette.quantonium,
                  // Against what is OPEN, not against the wall's ceiling:
                  // "0 / 5" would promise capacity the player has not bought.
                  figure: '$ready / $open',
                  // A level up from compiling: the cycle is burned into
                  // the AI itself, which is what the patches it pays buy.
                  action: ready > 0 ? 'ПРОШИТИ ×$ready' : 'ПРОШИТИ',
                  onAct: null,
                  // No height given: a rack knows how tall it has to be to
                  // still look like a rack, and says so.
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Drift(
                        progress: sim.driftProgress(now),
                        discount: sim.driftDiscount(now),
                        days: sim.driftDays(now),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var r = 0; r < fills.length; r++) ...[
                            Expanded(
                              child: ServerRack(
                                fill: fills[r],
                                phase: r,
                                locked: r >= open,
                              ),
                            ),
                            if (r < fills.length - 1) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Toward(held: held, cost: next),
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
      height: SimulationScreen._figure,
      child: OverflowBox(maxWidth: size, maxHeight: size, child: child),
    );
  }
}

/// The heat, and how much of it is left to build.
///
/// Named for the machine rather than for the maths (the code still calls it
/// drift): racks that have been grinding for days run hot, and a hot
/// datacentre overloads sooner. It is the one word that also explains the
/// CAP -- a room reaches its steady temperature and stops climbing -- and it
/// keeps working while the player is away, which is exactly when the melt
/// keeps running.
///
/// Cells rather than a smooth fill: this is a track the cycle CROSSES, and
/// what the player wants to know is how many days of relief are already
/// spent -- a pour would say only "somewhere in the middle". Sits above the
/// wall because it is what the wall stands on: every price below has already
/// had this taken off it.
class _Drift extends StatelessWidget {
  const _Drift({
    required this.progress,
    required this.discount,
    required this.days,
  });

  final double progress;
  final double discount;
  final double days;

  @override
  Widget build(BuildContext context) {
    final cap = PrototypeSimulation.collapseDriftCapDays.round();
    final melted = (discount * 100).toStringAsFixed(1);
    // Cold, and the only cold bar in the game: this is the one reading here
    // that works FOR the player while nothing is pressed, and it should not
    // be mistaken for the gold of cubes or the red of a full wall. Cold for
    // heat is deliberate -- the colour says whose side it is on, not what
    // temperature the room is.
    return HudProgress(
      fraction: progress,
      accent: Palette.steel,
      from: Palette.capsuleTree,
      label: 'НАГРІВ',
      // Days first, because days are what the cells are counting; the melt
      // second, because it is what the days BOUGHT. And "знижка" rather than
      // "поріг −2.5%": the wall below is priced in cubes, so the plain word
      // for a price that went down is the one the player already knows -- the
      // tree spends the same word on the same idea.
      reading: progress >= 1
          ? 'рівновага · знижка $melted%'
          : '${days.toStringAsFixed(1)} / $cap дн · знижка $melted%',
    );
  }
}

/// What the rack being filled still wants.
///
/// One readout under the wall rather than a caption under every rack: with
/// the ladder locked past the first, five captions were four blanks and a
/// stray figure. The pair reads like every other progress in the game --
/// what is held over what it takes -- and the same pile is what a Restart
/// pays, which is why the figure above says the same number.
class _Toward extends StatelessWidget {
  const _Toward({required this.held, required this.cost});

  final String held;

  /// Null once every open rack is full: there is nothing left to fill, and
  /// the line says so instead of quoting a price for capacity that does not
  /// exist yet.
  final String? cost;

  @override
  Widget build(BuildContext context) {
    final full = cost == null;
    final colour = full ? Palette.alarm : Palette.gold;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          full ? 'СТІНА ПОВНА' : 'НАСТУПНА СТІЙКА',
          style: AppText.body(
            8,
            weight: FontWeight.w800,
            color: colour.withValues(alpha: 0.7),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: colour.withValues(alpha: 0.14)),
          ),
        ),
        if (cost case final cost?) ...[
          const SizedBox(width: 9),
          Text(
            held,
            style: AppText.display(
              12.5,
              weight: FontWeight.w700,
              color: colour,
              height: 1,
            ),
          ),
          Text(
            ' / $cost',
            style: AppText.display(
              12.5,
              weight: FontWeight.w600,
              color: colour.withValues(alpha: 0.45),
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          const CubesIcon(size: 14),
        ],
      ],
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
    this.unit,
    this.body,
  });

  final String label;
  final Color colour;
  final String figure;

  /// The act itself. Where its payout is spent is a tab away, and a button
  /// that only changes tabs is a second name for something the navigation
  /// already says.
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
        HudButton(
          onTap: onAct,
          label: action,
          accent: colour,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ],
    );
  }
}
