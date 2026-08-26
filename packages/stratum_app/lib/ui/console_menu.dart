import 'package:flutter/widgets.dart';

import 'navigation.dart';
import 'tabler_icons.dart';
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
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0x99070A10)),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: AppMetrics.navTotal + 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.bar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x407FD9C4)),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 26),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 10, 4),
                  child: Row(
                    children: [
                      const Icon(Ti.terminal2, size: 16, color: Palette.tech),
                      const SizedBox(width: 8),
                      Text(
                        'КОНСОЛЬ',
                        style: AppText.body(
                          11.5,
                          weight: FontWeight.w800,
                          color: Palette.text,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Ti.close,
                            size: 15,
                            color: Palette.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 4, 11, 13),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Two columns, measured rather than assumed: the shell
                      // scales the whole design, so a hard-coded card width
                      // would only be right at one window size.
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
                              icon: Ti.playerPause,
                              label: 'Пауза',
                              note: 'усе завмирає до повернення',
                              onTap: onPause,
                            ),
                          ),
                          SizedBox(
                            width: card,
                            child: _Card(
                              icon: Ti.moon,
                              label: 'Фоновий режим',
                              note: 'гра працює, рендер вимкнено',
                              onTap: onBackground,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  final IconData icon;
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
                  child: Icon(icon, size: 14, color: Palette.tech),
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
