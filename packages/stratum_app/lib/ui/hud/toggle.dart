import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'plate.dart';
import 'tap.dart';

/// The house switch: a chamfered track with a knob, and the word it
/// governs beside it -- a bare toggle in a card full of controls does
/// not say which of them it routes.
class HudToggle extends StatelessWidget {
  const HudToggle({
    required this.on,
    required this.onTap,
    this.label,
    super.key,
  });

  final bool on;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // The knob is chamfered like its track and inset from the corners: a
    // square knob flush against the cut read as sticking out of the shape.
    final track = HudPlate(
      cut: 5,
      fill: on ? Palette.goldWell : Palette.shell,
      edge: on ? Palette.amber : Palette.lineBar,
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        width: 28,
        height: 12,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 110),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: HudPlate(
            cut: 3.5,
            fill: on ? Palette.gold : Palette.line,
            child: const SizedBox(width: 11, height: 11),
          ),
        ),
      ),
    );
    return HudTap(
      onTap: onTap,
      // The film would flood the caption beside the track too; the cursor
      // already answers hover, and the knob answers the tap.
      wash: false,
      child: label == null
          ? track
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!.toUpperCase(),
                  style: AppText.body(
                    8,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: on ? Palette.gold : Palette.textFaint,
                  ),
                ),
                const SizedBox(width: 6),
                track,
              ],
            ),
    );
  }
}
