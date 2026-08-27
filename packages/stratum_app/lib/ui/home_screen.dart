import 'package:flutter/widgets.dart';

import '../game.dart';
import 'stat.dart';
import 'tokens.dart';

/// The shell's own face: the AI looking at itself.
///
/// Shown when the player steps out of every screen. The islands are windows
/// into the simulation; this is the simulation's own status -- the cycle, the
/// running simulation, and the measurement data the prestige economy turns
/// on. The restart and collapse acts will live here too; until they are
/// built, their cards read out the numbers and say so.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final threshold = sim.collapseThreshold(
      DateTime.now().millisecondsSinceEpoch,
    );
    final saturation = threshold.isZero
        ? 0.0
        : (sim.rawData.value / threshold).toDouble().clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        AppMetrics.resourceBar + 8,
        16,
        AppMetrics.navTotal + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Text(
              'STRATUM',
              style: AppText.display(
                16,
                weight: FontWeight.w700,
                color: const Color(0x667FD9C4),
                letterSpacing: 9,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // No stretch here: a Column hands its children an unbounded height,
          // and a stretching Row would pass that infinity straight down.
          Row(
            children: [
              Expanded(
                child: _HomeCard(
                  child: Stat(
                    label: 'цикл',
                    value: '${sim.cycleNumber}',
                    colour: Palette.steel,
                    note: 'очок колапсу: ${sim.collapses.value}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeCard(
                  // The same word the mine uses for the same number: the shell
                  // must not rename what the player just looked at.
                  child: Stat(
                    label: 'глибина',
                    value: '${sim.layer.value} м',
                    colour: Palette.steel,
                    note: 'симуляція ${sim.simulationNumber}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HomeCard(
            child: Stat(
              label: 'сирі дані',
              note: 'за цикл: ${sim.cycleData.value}',
              // The headline of this screen, so it keeps a size of its own
              // rather than the house figure size.
              child: Text(
                '${sim.rawData.value}',
                style: AppText.display(
                  26,
                  weight: FontWeight.w700,
                  color: Palette.tech,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HomeCard(
            child: Stat(
              label: 'перезапуск',
              labelColour: Palette.gold,
              trailing: const _Soon(),
              value: '+${sim.bankableData.value}',
              colour: Palette.gold,
              note: 'забанкуєш · гаманець: ${sim.dataWallet.value}',
            ),
          ),
          const SizedBox(height: 10),
          _HomeCard(
            child: Stat(
              label: 'колапс',
              labelColour: Palette.quantonium,
              trailing: const _Soon(),
              value:
                  'перенасичення '
                  '${(saturation * 100).toStringAsFixed(1)}%',
              colour: Palette.quantonium,
              below: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 5),
                  _SaturationBar(fraction: saturation),
                  const SizedBox(height: 6),
                  Text(
                    'поріг $threshold · дрейф −3%/добу',
                    style: AppText.display(9.5, color: Palette.textFaint),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// A translucent panel, so the shell's field keeps showing through the home
/// screen instead of being walled off by it.
class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xC21E2834),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.lineBar),
      ),
      child: child,
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

/// How full the simulation is: raw data against the drifting threshold.
class _SaturationBar extends StatelessWidget {
  const _SaturationBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Palette.well),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // The sliver is kept visible even at nothing, so the gauge
              // reads as a gauge and not as a missing element.
              widthFactor: fraction < 0.015 ? 0.015 : fraction,
              child: const ColoredBox(color: Palette.quantonium),
            ),
          ],
        ),
      ),
    );
  }
}
