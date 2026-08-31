import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../hud.dart';
import '../tabler_icons.dart';
import '../tokens.dart';
import '../resource_icon.dart';

import 'package:stratum_core/stratum_core.dart';

import 'since_clock.dart';

/// The dark room the game keeps mining in.
///
/// Near-black on purpose -- dark pixels are what an OLED pays nothing for --
/// with a handful of live numbers, redrawn only when a tick lands. No ticker
/// runs anywhere on screen; the per-second cost is the text below.
class BackgroundOverlay extends StatelessWidget {
  const BackgroundOverlay({
    required this.game,
    required this.onExit,
    super.key,
  });

  final Game game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudTap(
      onTap: onExit,
      // Tap-anywhere surfaces keep the hand but not the film: a wash the
      // size of the screen reads as a glitch, not an affordance.
      wash: false,
      child: ColoredBox(
        color: const Color(0xFF03050A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ti.moon, size: 26, color: Color(0x597FD9C4)),
            const SizedBox(height: 14),
            Text(
              'ФОНОВИЙ РЕЖИМ',
              style: AppText.body(
                11,
                weight: FontWeight.w800,
                color: const Color(0x8CA0ADC1),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '${sim.layer.value + 1} м',
              style: AppText.display(
                34,
                weight: FontWeight.w700,
                color: const Color(0xB3FFD782),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DimResource(
                  id: ResourceId.regolith,
                  value: '${sim.regolith.value}',
                ),
                const SizedBox(width: 18),
                _DimResource(
                  id: ResourceId.crystals,
                  value: '${sim.crystals.value}',
                ),
                const SizedBox(width: 18),
                _DimResource(
                  id: ResourceId.quantonium,
                  value: '${sim.quantonium.value}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SinceClock(
              since: game.backgroundAt ?? DateTime.now(),
              prefix: 'у фоні',
              color: const Color(0x8CA0ADC1),
            ),
            const SizedBox(height: 18),
            Text(
              'симуляція працює · рендер вимкнено',
              style: AppText.body(9.5, color: const Color(0x667C8A9C)),
            ),
            const SizedBox(height: 4),
            Text(
              'торкнись, щоб повернутись',
              style: AppText.body(9.5, color: const Color(0x667C8A9C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimResource extends StatelessWidget {
  const _DimResource({required this.id, required this.value});

  final ResourceId id;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceIcon(id, size: 17, colour: const Color(0x66A0ADC1)),
        const SizedBox(width: 5),
        Text(
          value,
          style: AppText.display(
            13,
            weight: FontWeight.w600,
            color: const Color(0x99D6DDE9),
          ),
        ),
      ],
    );
  }
}
