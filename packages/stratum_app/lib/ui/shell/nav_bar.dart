import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../game_icons.dart';
import '../hud.dart';
import '../navigation.dart';
import '../tokens.dart';
import 'dotted.dart';
import 'screen_strip.dart';

/// The two-level navigation: sections along the bottom, and the current
/// section's screens on a strip above them.
///
/// The strip is always there. Folding it away saved 44 pixels and cost the
/// player their bearings: where you are and what else is here should not be
/// something you have to tap to find out. Screens reserve the room through
/// [AppMetrics.navTotal].
class NavBar extends StatelessWidget {
  const NavBar({
    required this.game,
    required this.screen,
    required this.console,
    required this.onSection,
    required this.onScreen,
    super.key,
  });

  final Game game;

  /// The open screen, or null when the player has stepped out to the shell.
  final GameScreen? screen;

  /// Whether the console panel is showing, which is the one section that has
  /// no strip of its own.
  final bool console;

  final ValueChanged<NavSection> onSection;
  final ValueChanged<GameScreen> onScreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The row keeps its height with nothing in it: panels anchor to
        // [AppMetrics.navTotal], and a bar that changed height would leave
        // them floating.
        SizedBox(
          height: AppMetrics.navStrip,
          child: screen == null
              ? null
              : ScreenStrip(
                  game: game,
                  section: screen!.section,
                  screen: screen!,
                  onScreen: onScreen,
                ),
        ),
        // No bar behind it: the icons and chips carry their own shapes, so a
        // slab under them only walls the shell off from its own navigation.
        SizedBox(
          height: AppMetrics.navBar,
          // Each tab centres itself in the full height, so the seated icon
          // sits on the bar's middle line rather than on whatever is left
          // after a padding.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final section in NavSection.values)
                // A centred cluster: the seated well is 46 wide, and a fixed
                // slot keeps the tabs together in the middle. 78 was a
                // cluster while there were four sections; at five it filled
                // the row exactly, which reads as spread, not seated.
                SizedBox(
                  width: 64,
                  child: _SectionTab(
                    section: section,
                    current: section == screen?.section,
                    open: section.opensAsPanel && console,
                    marked: sectionNeedsAttention(section, game),
                    onTap: () => onSection(section),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A section, as an icon alone.
///
/// Without a label the current section has to be unmistakable, so it is not
/// only tinted but seated in a lit well -- colour alone reads as "slightly
/// different", a filled shape reads as "this one".
class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.section,
    required this.current,
    required this.open,
    required this.marked,
    required this.onTap,
  });

  final NavSection section;
  final bool current;
  final bool open;

  /// Whether anything inside this section can be acted on.
  final bool marked;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lit = current || open;
    // The console does not take you anywhere: it lays a sheet over whatever
    // you were looking at. So it lights in the sheet's own green rather than
    // the gold that means "this is the screen you are on" -- the bar tells
    // you which of its slots changes the view and which covers it.
    final accent = section.opensAsPanel ? Palette.tech : Palette.gold;
    // The section bar is icons only, so without a label it is unreadable to
    // anything that cannot see -- a screen reader, or a test driver.
    return Semantics(
      label: section.label,
      button: true,
      selected: lit,
      child: Center(
        child: Dotted(
          marked: marked && !current,
          child: SizedBox(
            width: 46,
            height: 32,
            child: HudMenu(
              onTap: onTap,
              active: lit,
              accent: accent,
              cut: 7,
              padding: EdgeInsets.zero,
              child: Center(
                child: GameIcon(
                  section.icon,
                  size: 21,
                  colour: lit ? accent : Palette.textFaint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
