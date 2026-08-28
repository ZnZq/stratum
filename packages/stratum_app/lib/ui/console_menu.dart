import 'package:flutter/widgets.dart';

import 'navigation.dart';
import 'game_icons.dart';
import 'game_modal.dart';
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
    super.key,
  });

  final ValueChanged<GameScreen> onPick;

  /// Whole-game switches live here too: they are one-tap acts, not places,
  /// but the console is the game's service hatch and this is where a player
  /// looks for them.
  final VoidCallback onPause;
  final VoidCallback onBackground;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GameModal(
      icon: Ic.console,
      title: 'КОНСОЛЬ',
      anchor: ModalAnchor.bottom,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          color: Palette.well,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.lineBar),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Palette.bar,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.line),
                  ),
                  child: GameIcon(icon, size: 15, colour: Palette.tech),
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
      ),
    );
  }
}
