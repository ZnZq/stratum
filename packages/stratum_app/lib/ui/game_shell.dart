import 'package:flutter/widgets.dart';

import '../game.dart';
import 'console_menu.dart';
import 'drill_screen.dart';
import 'navigation.dart';
import 'save_menu.dart';
import 'shell_backdrop.dart';
import 'upgrades_screen.dart';
import 'tabler_icons.dart';
import 'tokens.dart';
import 'warehouse.dart';

/// The width every screen is laid out against.
///
/// The interface is drawn once at a phone's width and scaled uniformly to
/// whatever it is given, so a desktop window shows the same design larger
/// rather than the same design adrift in empty space. The window's aspect is
/// locked, so the scale is never distorted; leftover height simply becomes more
/// design height, which the strata scene absorbs.
const double _designWidth = 390;

/// The phone frame: status strip, resource bar, the active screen, and the tabs.
class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final Game _game = Game();

  /// The open screen, or null for the shell itself.
  ///
  /// Nothing is a place the player can be: tapping the section you are already
  /// in puts the screen away and hands the shell back, so the game does not
  /// insist on covering itself.
  GameScreen? _screen = GameScreen.drill;

  /// Where each section was left. Coming back to a section returns to what the
  /// player was doing in it rather than to its first entry.
  final Map<NavSection, GameScreen> _lastIn = {};

  bool _warehouse = false;
  bool _saves = false;
  bool _console = false;

  void _pickSection(NavSection section) {
    if (section.opensAsPanel) {
      setState(() {
        _console = !_console;
        _warehouse = false;
        _saves = false;
      });
      return;
    }
    setState(() {
      _console = false;
      if (_screen?.section == section) {
        _screen = null;
        return;
      }
      _screen = _lastIn[section] ?? section.landing;
    });
  }

  void _pickScreen(GameScreen screen) {
    if (screen.isOverlay) {
      _openOverlay(screen);
      return;
    }
    setState(() {
      _console = false;
      _screen = screen;
      _lastIn[screen.section] = screen;
    });
  }

  void _openOverlay(GameScreen screen) {
    if (screen != GameScreen.saves) return;
    setState(() {
      _saves = true;
      _console = false;
      _warehouse = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // Reads the autosave and only then starts the loops, so the first cycle
    // never runs against a default state that is about to be replaced.
    _game.start();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.shell,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / _designWidth;
            // FittedBox, not Transform: the incoming constraints are tight, so
            // a SizedBox under them cannot pick its own width. FittedBox lays
            // the child out unbounded, letting it take the design width, and
            // scales the result to fill.
            return FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _designWidth,
                height: constraints.maxHeight / scale,
                child: ListenableBuilder(
                  listenable: _game,
                  // TickerMode reaches every createTicker below it, so the
                  // backdrop dust, the flutes and the floats all freeze with
                  // the engines -- the pause can then be shown through glass
                  // instead of being hidden behind a wall.
                  // The screen runs edge to edge and the chrome floats over it,
                  // so the borehole is never boxed inside a panel.
                  builder: (context, _) => TickerMode(
                    enabled: !_game.paused,
                    child: Stack(
                      children: [
                        // The shell itself, still to be designed. Screens are
                        // islands laid on it, so whatever ends up here shows
                        // around their edges instead of being covered.
                        const Positioned.fill(child: ShellBackdrop()),
                        if (_screen case final screen?)
                          Positioned.fill(
                            child: _Island(
                              child: switch (screen) {
                                GameScreen.drill => DrillScreen(game: _game),
                                GameScreen.upgrades => UpgradesScreen(
                                  game: _game,
                                ),
                                _ => _Placeholder(screen: screen),
                              },
                            ),
                          ),
                        // Positioned.fill, not a bare child: the sheet is a
                        // Stack of positioned children, which under the loose
                        // constraints a non-positioned Stack child gets would
                        // size itself to nothing.
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: switch ((_warehouse, _saves, _console)) {
                              (true, _, _) => WarehouseSheet(
                                game: _game,
                                onClose: () =>
                                    setState(() => _warehouse = false),
                              ),
                              (_, true, _) => SaveMenu(
                                game: _game,
                                onClose: () => setState(() => _saves = false),
                              ),
                              (_, _, true) => ConsoleMenu(
                                onPick: _pickScreen,
                                onClose: () => setState(() => _console = false),
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                        ),
                        if (_game.paused)
                          Positioned.fill(
                            child: _PauseOverlay(onResume: _game.resume),
                          ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _ResourceBar(
                            game: _game,
                            open: _warehouse,
                            onTap: () => setState(() {
                              _warehouse = !_warehouse;
                              _saves = false;
                              _console = false;
                            }),
                            onSaves: () => setState(() {
                              _saves = !_saves;
                              _warehouse = false;
                              _console = false;
                            }),
                            onPause: _game.pause,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _NavBar(
                            game: _game,
                            screen: _screen,
                            console: _console,
                            onSection: _pickSection,
                            onScreen: _pickScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The short version of the warehouse, and the way into the long one.
/// A screen, inset from the chrome and floating on the shell.
///
/// Screens used to run edge to edge and each one padded itself clear of the
/// resource strip and the tabs. Doing it once here means a screen lays out
/// against its own box and never has to know what is stacked over the app.
class _Island extends StatelessWidget {
  const _Island({required this.child});

  final Widget child;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        AppMetrics.resourceBar,
        8,
        AppMetrics.navTotal + 4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: Palette.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        // A hair inside the border, so the clip never eats it.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - 1),
          child: child,
        ),
      ),
    );
  }
}

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({
    required this.game,
    required this.open,
    required this.onTap,
    required this.onSaves,
    required this.onPause,
  });

  final Game game;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onSaves;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: AppMetrics.resourceBar,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF20B0C10), Color(0xB30B0C10), Color(0x000B0C10)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  _Resource(
                    icon: Ti.stack2,
                    colour: Palette.ore,
                    value: '${sim.ore.value}',
                  ),
                  const SizedBox(width: 13),
                  _Resource(
                    icon: Ti.atom2,
                    colour: Palette.quantonium,
                    value: '${sim.quantonium.value}',
                  ),
                  const SizedBox(width: 13),
                  _Resource(
                    icon: Ti.diamond,
                    colour: Palette.crystal,
                    value: '${sim.crystals.value}',
                  ),
                  const SizedBox(width: 13),
                  _Resource(
                    icon: Ti.cpu,
                    colour: Palette.compute,
                    value: '${sim.backgroundCompute.value}',
                  ),
                ],
              ),
            ),
            _Resource(
              icon: Ti.capsule,
              colour: Palette.gold,
              value: '${sim.capsules.value}',
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(
                Ti.chevronDown,
                size: 13,
                color: Palette.textFaint,
              ),
            ),
            // Its own gesture inside the strip's: children are hit-tested
            // first, so the gear opens the saves and everything around it
            // still opens the warehouse.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSaves,
              child: const Padding(
                padding: EdgeInsets.only(left: 10, top: 4, bottom: 4),
                child: Icon(Ti.settings2, size: 15, color: Palette.textMuted),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPause,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Icon(Ti.playerPause, size: 15, color: Palette.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The frozen game, said out loud.
///
/// Glass, not a wall: TickerMode above has already frozen every animation in
/// the scene, so the stillness underneath IS the message and deserves to be
/// seen. The tint only says "input goes to me now".
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResume,
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
            const SizedBox(height: 6),
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

class _Resource extends StatelessWidget {
  const _Resource({
    required this.icon,
    required this.colour,
    required this.value,
  });

  final IconData icon;
  final Color colour;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colour),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppText.display(12.5, weight: FontWeight.w700, color: colour),
        ),
      ],
    );
  }
}

/// The two-level navigation: sections along the bottom, and the current
/// section's screens on a strip above them.
///
/// The strip is always there. Folding it away saved 44 pixels and cost the
/// player their bearings: where you are and what else is here should not be
/// something you have to tap to find out. Screens reserve the room through
/// [AppMetrics.navTotal].
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.game,
    required this.screen,
    required this.console,
    required this.onSection,
    required this.onScreen,
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
              : _ScreenStrip(
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
                // Both rows divide the same full width, so a section sits
                // under the chips rather than beside them.
                Expanded(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: _Dotted(
          marked: marked && !current,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lit ? Palette.goldWell : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: lit ? Palette.amber : const Color(0x00000000),
              ),
            ),
            child: Icon(
              section.icon,
              size: 21,
              color: lit ? Palette.gold : Palette.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small dot in the top-right corner of whatever it wraps.
class _Dotted extends StatelessWidget {
  const _Dotted({required this.marked, required this.child});

  final bool marked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!marked) return child;
    return Stack(
      clipBehavior: Clip.none,
      // Passthrough, not the default loose fit: a tab in an Expanded is given
      // a tight width, and loosening it would let the marked one shrink to
      // its own size while its unmarked neighbours filled their share.
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Palette.tech,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.page, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenStrip extends StatelessWidget {
  const _ScreenStrip({
    required this.game,
    required this.section,
    required this.screen,
    required this.onScreen,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _Dotted(
        marked: marked && !active,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: active ? Palette.goldWell : Palette.well,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? Palette.amber : Palette.lineBar),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(screen.icon, size: 16, color: colour),
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.screen});

  final GameScreen screen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(screen.icon, size: 26, color: Palette.textFaint),
          const SizedBox(height: 10),
          Text(screen.label.toUpperCase(), style: AppText.eyebrow()),
          const SizedBox(height: 6),
          Text(
            'наступний прохід',
            style: AppText.body(12, color: Palette.textFaint),
          ),
        ],
      ),
    );
  }
}
