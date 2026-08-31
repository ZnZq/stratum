import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../game_icons.dart';
import '../hud.dart';
import '../navigation.dart';
import '../tokens.dart';
import 'dotted.dart';

class ScreenStrip extends StatelessWidget {
  const ScreenStrip({
    required this.game,
    required this.section,
    required this.screen,
    required this.onScreen,
    super.key,
  });

  final Game game;
  final NavSection section;
  final GameScreen screen;
  final ValueChanged<GameScreen> onScreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // Centred when the section's screens fit and scrollable when they do
      // not, so a section can grow past four entries without being redesigned.
      // An equal share each, rather than intrinsic widths in a scroller: the
      // row then fills the strip whether a section has three screens or six,
      // and nothing can scroll out of reach.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final entry in section.screens)
            Expanded(
              child: _ScreenChip(
                screen: entry,
                active: entry == screen,
                marked: screenNeedsAttention(entry, game),
                onTap: () => onScreen(entry),
              ),
            ),
        ],
      ),
    );
  }
}

/// A screen, as an icon over its name.
///
/// This is the level the player actually moves between, so it is the level
/// that gets the words.
class _ScreenChip extends StatelessWidget {
  const _ScreenChip({
    required this.screen,
    required this.active,
    required this.marked,
    required this.onTap,
  });

  final GameScreen screen;
  final bool active;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = active ? Palette.gold : Palette.textDim;
    return Dotted(
      marked: marked && !active,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: HudMenu(
          onTap: onTap,
          active: active,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GameIcon(screen.icon, size: 16, colour: colour),
              const SizedBox(height: 2),
              Text(
                screen.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.body(
                  9,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
