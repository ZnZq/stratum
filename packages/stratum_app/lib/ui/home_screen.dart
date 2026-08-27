import 'package:flutter/widgets.dart';

import '../game.dart';
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
          Row(
            children: [
              Expanded(
                child: _HomeCard(
                  label: 'ЦИКЛ ${sim.cycleNumber}',
                  child: _Readout(
                    value: '${sim.collapses.value}',
                    colour: Palette.steel,
                    caption: 'очок колапсу',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeCard(
                  label: 'СИМУЛЯЦІЯ ${sim.simulationNumber}',
                  child: _Readout(
                    value: '${sim.layer.value} м',
                    colour: Palette.steel,
                    caption: 'поточна глибина',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HomeCard(
            label: 'СИРІ ДАНІ',
            child: _Readout(
              value: '${sim.rawData.value}',
              colour: Palette.tech,
              size: 24,
              caption: 'за цикл: ${sim.cycleData.value}',
            ),
          ),
          const SizedBox(height: 10),
          _HomeCard(
            label: 'ПЕРЕЗАПУСК',
            chip: 'згодом',
            child: _Readout(
              value: '+${sim.bankableData.value}',
              colour: Palette.gold,
              caption: 'забанкуєш · гаманець: ${sim.dataWallet.value}',
            ),
          ),
          const SizedBox(height: 10),
          _HomeCard(
            label: 'КОЛАПС',
            chip: 'згодом',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'перенасичення ${(saturation * 100).toStringAsFixed(1)}%',
                  style: AppText.display(
                    15,
                    weight: FontWeight.w700,
                    color: Palette.quantonium,
                  ),
                ),
                const SizedBox(height: 7),
                _SaturationBar(fraction: saturation),
                const SizedBox(height: 6),
                Text(
                  'поріг $threshold · дрейф −3%/добу',
                  style: AppText.body(9.5, color: Palette.textMuted),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// A translucent card, so the shell's field keeps showing through the home
/// screen instead of being walled off by it.
class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.label, required this.child, this.chip});

  final String label;
  final Widget child;

  /// A small trailing tag, used to mark an act that is not built yet.
  final String? chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xC21E2834),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body(
                    9.5,
                    weight: FontWeight.w700,
                    color: Palette.textFaint,
                  ).copyWith(letterSpacing: 1.6),
                ),
              ),
              if (chip case final chip?)
                Container(
                  padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
                  decoration: BoxDecoration(
                    color: Palette.bar,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Palette.lineBar),
                  ),
                  child: Text(
                    chip,
                    style: AppText.body(8.5, color: Palette.textFaint),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.value,
    required this.colour,
    required this.caption,
    this.size = 17,
  });

  final String value;
  final Color colour;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppText.display(size, weight: FontWeight.w700, color: colour),
        ),
        const SizedBox(height: 3),
        Text(caption, style: AppText.body(9.5, color: Palette.textMuted)),
      ],
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
        height: 8,
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
