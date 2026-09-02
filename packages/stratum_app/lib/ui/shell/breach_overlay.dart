import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../hud.dart';
import '../save_menu.dart';
import '../tokens.dart';
import '../clock_text.dart';

/// The clock has been wound back past what the save already lived.
///
/// Unclosable on purpose: the save's last observed moment is in the
/// player's future, and the simulation refuses to run until reality
/// catches up. The one door out is loading a save that was not played
/// against a wound clock.
class BreachOverlay extends StatefulWidget {
  const BreachOverlay({required this.game, required this.untilMs, super.key});

  final Game game;
  final int untilMs;

  @override
  State<BreachOverlay> createState() => _BreachOverlayState();
}

class _BreachOverlayState extends State<BreachOverlay> {
  bool _saves = false;

  String _countdown() =>
      hmsClock(widget.untilMs - DateTime.now().millisecondsSinceEpoch);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // No GestureDetector: there is nothing to tap out to.
        const ColoredBox(color: Color(0xE60A0E15)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HudLamp(colour: Palette.alarm),
                const SizedBox(height: 14),
                Text(
                  'ЗБІЙ СИМУЛЯЦІЇ',
                  style: AppText.body(
                    14,
                    weight: FontWeight.w800,
                    color: Palette.alarm,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'остання зафіксована активність — у майбутньому. '
                  'Ремонтні роботи тривають, доки реальний час не '
                  'наздожене симуляцію.',
                  textAlign: TextAlign.center,
                  style: AppText.body(11, color: Palette.textMuted),
                ),
                const SizedBox(height: 18),
                Text(
                  _countdown(),
                  style: AppText.display(
                    30,
                    weight: FontWeight.w700,
                    color: Palette.alarm,
                  ),
                ),
                Text(
                  'до завершення ремонту',
                  style: AppText.body(9.5, color: Palette.textFaint),
                ),
                const SizedBox(height: 22),
                HudButton(
                  onTap: () => setState(() => _saves = true),
                  label: 'ЗБЕРЕЖЕННЯ',
                  accent: Palette.tech,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 9),
                ),
                const SizedBox(height: 8),
                Text(
                  'або завантажте сейв, де час не крутили',
                  style: AppText.body(9, color: Palette.textFaint),
                ),
              ],
            ),
          ),
        ),
        if (_saves)
          SaveMenu(
            game: widget.game,
            // The breach covers the shell, so no strip stands under it.
            floor: AppMetrics.navBar,
            onClose: () => setState(() => _saves = false),
          ),
      ],
    );
  }
}
