import 'dart:async';

import 'package:flutter/widgets.dart';

import '../game.dart';
import '../preferences.dart';
import 'console_menu.dart';
import 'craft_screen.dart';
import 'drills_screen.dart';
import 'financing_sheet.dart';
import 'drill_screen.dart';
import 'hud.dart';
import 'home_screen.dart';
import 'navigation.dart';
import 'notices.dart';
import 'offline_window.dart';
import 'save_menu.dart';
import 'strikes_screen.dart';
import 'simulation_screen.dart';
import 'trade_screen.dart';
import 'tree_screen.dart';
import 'shell_backdrop.dart';
import 'tokens.dart';
import 'warehouse.dart';
import 'shell/background_overlay.dart';
import 'shell/breach_overlay.dart';
import 'shell/nav_bar.dart';
import 'shell/pause_overlay.dart';
import 'shell/resource_bar.dart';
import 'building_screen.dart';
import 'replicator_screen.dart';
import 'shell/screen_placeholder.dart';

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

  bool _saves = false;
  bool _finance = false;

  bool _console = false;

  void _pickSection(NavSection section) {
    if (section.opensAsPanel) {
      setState(() {
        _console = !_console;
        _saves = false;
        _finance = false;
      });
      return;
    }
    setState(() {
      _console = false;
      if (_screen?.section == section) {
        _screen = null;
        return;
      }
      _saves = false;
      _finance = false;
      _screen = _lastIn[section] ?? section.landing;
    });
    _syncAudience();
    _rememberScreen();
  }

  /// Everything the mine says belongs to the mine; any other screen mutes it.
  void _syncAudience() {
    _game.setWatched(_screen == GameScreen.drill);
  }

  /// A screen inside its frame.
  ///
  /// The frame wears the screen's own colour: a tree is read by what it
  /// spends, so the border says which wallet is at stake before a single node
  /// is drawn. Everything else keeps the house grey.
  Widget _framed(GameScreen screen) {
    final accent = switch (screen) {
      GameScreen.tree => TreeKind.simulation.accent,
      GameScreen.firmware => TreeKind.firmware.accent,
      // The third tree's frame: its currency is material (components),
      // so it wears the production branch's steel.
      GameScreen.building => Palette.steel,
      _ => Palette.tech,
    };
    return HudScreen(
      accent: accent,
      edge: accent == Palette.tech
          ? Palette.line
          : accent.withValues(alpha: 0.34),
      child: switch (screen) {
        GameScreen.drill => DrillScreen(game: _game),
        GameScreen.upgrades => DrillsScreen(game: _game),
        GameScreen.strikes => StrikesScreen(game: _game),
        GameScreen.warehouse => WarehouseScreen(game: _game),
        GameScreen.trade => TradeScreen(game: _game),
        GameScreen.craft => CraftScreen(game: _game),
        GameScreen.building => BuildingScreen(game: _game),
        GameScreen.replicator => ReplicatorScreen(game: _game),
        GameScreen.simulation => SimulationScreen(
          game: _game,
          onOpen: _pickScreen,
        ),
        GameScreen.tree => TreeScreen(kind: TreeKind.simulation, game: _game),
        GameScreen.firmware => TreeScreen(kind: TreeKind.firmware, game: _game),
        _ => ScreenPlaceholder(screen: screen),
      },
    );
  }

  void _pickScreen(GameScreen screen) {
    if (screen.isOverlay) {
      _openOverlay(screen);
      return;
    }
    setState(() {
      // Moving anywhere dismisses whatever sheet was open: navigation under
      // a modal that stays put switches the WRONG layer -- the screens
      // changed behind the sheet while the sheet pretended to be the room.
      _console = false;
      _saves = false;
      _finance = false;
      _screen = screen;
      _lastIn[screen.section] = screen;
    });
    if (screen == GameScreen.upgrades) _game.markDrillUpgradesSeen();
    _syncAudience();
    _rememberScreen();
  }

  void _openOverlay(GameScreen screen) {
    if (screen != GameScreen.saves) return;
    setState(() {
      _saves = true;
      _console = false;
      _finance = false;
    });
  }

  /// Where the player was looking, kept beside the saves rather than in
  /// one: a save is the run, and loading an old slot must not move the
  /// camera.
  final Preferences _prefs = Preferences();

  static const String _screenKey = 'screen';

  /// Standing on the shell is a PLACE, not the absence of one. Writing null
  /// for it made the note indistinguishable from "nothing saved yet", so a
  /// player who quit from the Data Centre came back to the mine.
  static const String _shellValue = 'shell';

  void _rememberScreen() =>
      unawaited(_prefs.set(_screenKey, _screen?.name ?? _shellValue));

  @override
  void initState() {
    super.initState();
    // Reads the autosave and only then starts the loops, so the first cycle
    // never runs against a default state that is about to be replaced.
    _game.start();
    unawaited(_restoreScreen());
  }

  Future<void> _restoreScreen() async {
    await _prefs.load();
    if (!mounted) return;
    final saved = _prefs[_screenKey];
    if (saved is! String) return;
    if (saved == _shellValue) {
      setState(() => _screen = null);
      _syncAudience();
      return;
    }
    // A screen this build no longer has is not an error -- the note may be
    // older than the navigation. Landing on the shell is the right fallback.
    final found = GameScreen.values
        .where((screen) => screen.name == saved && !screen.isOverlay)
        .firstOrNull;
    setState(() {
      _screen = found;
      if (found case final screen?) _lastIn[screen.section] = screen;
    });
    if (found == GameScreen.upgrades) _game.markDrillUpgradesSeen();
    _syncAudience();
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
                  builder: (context, _) => Stack(
                    children: [
                      Positioned.fill(
                        child: TickerMode(
                          enabled: !_game.paused && !_game.background,
                          child: Stack(
                            children: [
                              // The shell itself, still to be designed. Screens are
                              // islands laid on it, so whatever ends up here shows
                              // around their edges instead of being covered.
                              const Positioned.fill(child: ShellBackdrop()),
                              if (_screen == null)
                                Positioned.fill(child: HomeScreen()),
                              if (_screen case final screen?)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      AppMetrics.resourceBar,
                                      8,
                                      AppMetrics.navTotal + 4,
                                    ),
                                    child: _framed(screen),
                                  ),
                                ),
                              // Positioned.fill, not a bare child: the sheet is a
                              // Stack of positioned children, which under the loose
                              // constraints a non-positioned Stack child gets would
                              // size itself to nothing.
                              Positioned.fill(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: switch ((_saves, _console, _finance)) {
                                    (true, _, _) => SaveMenu(
                                      game: _game,
                                      onClose: () =>
                                          setState(() => _saves = false),
                                    ),
                                    (_, _, true) => FinancingSheet(
                                      game: _game,
                                      onClose: () =>
                                          setState(() => _finance = false),
                                    ),
                                    (_, true, _) => ConsoleMenu(
                                      onPick: _pickScreen,
                                      onPause: () {
                                        setState(() => _console = false);
                                        _game.pause();
                                      },
                                      onBackground: () {
                                        setState(() => _console = false);
                                        _game.setBackground(true);
                                      },
                                      onClose: () =>
                                          setState(() => _console = false),
                                    ),
                                    _ => const SizedBox.shrink(),
                                  },
                                ),
                              ),
                              if (_game.paused)
                                Positioned.fill(
                                  child: PauseOverlay(
                                    since: _game.pausedAt ?? DateTime.now(),
                                    onResume: _game.resume,
                                  ),
                                ),
                              if (_game.breachUntilMs case final until?)
                                Positioned.fill(
                                  child: BreachOverlay(
                                    game: _game,
                                    untilMs: until,
                                  ),
                                ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: ResourceBar(
                                  game: _game,
                                  onTap: () => setState(() {
                                    _finance = !_finance;
                                    _saves = false;
                                    _console = false;
                                  }),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: NavBar(
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
                      if (_game.offlineArrival case final arrival?)
                        Positioned.fill(
                          child: OfflineWindow(
                            gain: arrival.gain,
                            away: arrival.away,
                            onClose: _game.dismissOffline,
                          ),
                        ),
                      if (_game.background)
                        Positioned.fill(
                          child: BackgroundOverlay(
                            game: _game,
                            onExit: () => _game.setBackground(false),
                          ),
                        ),
                      // Above the pause glass and outside its TickerMode: a
                      // save fired by the pause itself still gets its card,
                      // animated, while everything underneath stands still.
                      NoticeLayer(game: _game),
                    ],
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
