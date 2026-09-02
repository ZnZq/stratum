import 'package:flutter/widgets.dart';

import 'navigation.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'tokens.dart';

/// The console: everything around the game rather than in it.
///
/// A panel of cards instead of the strip the other sections use. Its entries
/// are not places the player moves between while playing -- each is somewhere
/// you go, do one thing, and come back from -- so they get room to say what
/// they are rather than a row of chips to squint at.
class ConsoleMenu extends StatelessWidget {
  const ConsoleMenu({
    required this.onPick,
    required this.onPause,
    required this.onBackground,
    required this.onClose,
    required this.floor,
    super.key,
  });

  final ValueChanged<GameScreen> onPick;

  /// What the navigation takes under the sheet; see [HudModal.floor].
  final double floor;

  /// Whole-game switches live here too: they are one-tap acts, not places,
  /// but the console is the game's service hatch and this is where a player
  /// looks for them.
  final VoidCallback onPause;
  final VoidCallback onBackground;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return HudModal(
      icon: Ic.console,
      title: 'КОНСОЛЬ',
      anchor: ModalAnchor.bottom,
      floor: floor,
      onClose: onClose,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two columns, measured rather than assumed: the shell scales the
          // whole design, so a hard-coded card width would only be right at
          // one window size.
          const gap = 8.0;
          final card = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final screen in NavSection.console.screens)
                SizedBox(
                  width: card,
                  child: _Card(
                    icon: screen.icon,
                    label: screen.label,
                    note: screen.note,
                    onTap: () => onPick(screen),
                  ),
                ),
              SizedBox(
                width: card,
                child: _Card(
                  icon: Ic.pause,
                  label: 'Пауза',
                  note: 'усе завмирає до повернення',
                  onTap: onPause,
                ),
              ),
              SizedBox(
                width: card,
                child: _Card(
                  icon: Ic.background,
                  label: 'Фоновий режим',
                  note: 'гра працює, рендер вимкнено',
                  onTap: onBackground,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.label,
    required this.note,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudMenu(
      onTap: onTap,
      accent: Palette.tech,
      cut: 10,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: HudPlate(
                  cut: 6,
                  fill: Palette.bar,
                  edge: Palette.line,
                  child: Center(
                    child: GameIcon(icon, size: 15, colour: Palette.tech),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    11.5,
                    weight: FontWeight.w700,
                    color: Palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(9.5, color: Palette.textMuted),
          ),
        ],
      ),
    );
  }
}
