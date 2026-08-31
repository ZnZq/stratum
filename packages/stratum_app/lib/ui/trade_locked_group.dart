import 'package:flutter/widgets.dart';

import 'hud.dart';
import 'tokens.dart';

/// A family the game has not built yet. Honest about why it is shut.
class LockedGroup extends StatelessWidget {
  const LockedGroup({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      cut: 11,
      fill: Palette.shell.withValues(alpha: 0.5),
      edge: Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.textFaint,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                'відкриється з крафтом',
                style: AppText.body(9, color: Palette.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var slot = 0; slot < 3; slot++) ...[
                if (slot > 0) const SizedBox(width: 6),
                const HudPlate(
                  cut: 7,
                  fill: Palette.shell,
                  edge: Palette.lineBar,
                  child: SizedBox(width: 30, height: 30),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
