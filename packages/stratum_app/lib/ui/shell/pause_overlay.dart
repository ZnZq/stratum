import 'package:flutter/widgets.dart';

import '../hud.dart';
import '../tabler_icons.dart';
import '../tokens.dart';
import 'since_clock.dart';

/// The frozen game, said out loud.
///
/// Glass, not a wall: TickerMode above has already frozen every animation in
/// the scene, so the stillness underneath IS the message and deserves to be
/// seen. The tint only says "input goes to me now".
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({required this.since, required this.onResume, super.key});

  final DateTime since;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onResume,
      wash: false,
      child: ColoredBox(
        color: const Color(0x8A0B1018),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.well,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x4D7FD9C4)),
              ),
              child: const Icon(Ti.playerPlay, size: 26, color: Palette.tech),
            ),
            const SizedBox(height: 16),
            Text(
              'ПАУЗА',
              style: AppText.display(
                20,
                weight: FontWeight.w700,
                color: Palette.text,
                letterSpacing: 8,
                shadows: true,
              ),
            ),
            const SizedBox(height: 8),
            SinceClock(
              since: since,
              prefix: 'на паузі',
              color: Palette.textDim,
            ),
            const SizedBox(height: 8),
            Text(
              'симуляція завмерла · торкнись, щоб продовжити',
              style: AppText.body(10.5, color: Palette.textDim, shadows: true),
            ),
          ],
        ),
      ),
    );
  }
}
