import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import '../preferences.dart';
import 'console_menu.dart';
import 'drills_screen.dart';
import 'financing_sheet.dart';
import 'drill_screen.dart';
import 'game_icons.dart';
import 'gauge.dart';
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
import 'resource_style.dart';
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
        GameScreen.simulation => SimulationScreen(
          game: _game,
          onOpen: _pickScreen,
        ),
        GameScreen.tree => TreeScreen(kind: TreeKind.simulation, game: _game),
        GameScreen.firmware => TreeScreen(kind: TreeKind.firmware, game: _game),
        _ => _Placeholder(screen: screen),
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
                                  child: _PauseOverlay(
                                    since: _game.pausedAt ?? DateTime.now(),
                                    onResume: _game.resume,
                                  ),
                                ),
                              if (_game.breachUntilMs case final until?)
                                Positioned.fill(
                                  child: _BreachOverlay(
                                    game: _game,
                                    untilMs: until,
                                  ),
                                ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _ResourceBar(
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
                          child: _BackgroundOverlay(
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

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({required this.game, required this.onTap});

  final Game game;

  /// The strip means ONE thing now: the whole of it opens financing. The
  /// warehouse moved to its own production tab when the strip stopped being
  /// its short form.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudTap(
      onTap: onTap,
      // The strip is a full-width surface over the scene: a rectangular
      // hover film across it reads as a glitch, the same lesson as the
      // overlays. The hand cursor alone says it opens something.
      wash: false,
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
        // Financing wears the strip now; the resources moved wholly into
        // the warehouse the chevron still opens. The strip was already the
        // warehouse's short form -- the round gauge is the financing
        // sheet's short form by the same rule.
        child: Row(
          children: [
            Expanded(
              // The badge SITS ON the gauge: the bar slides in from behind
              // the round it is filling, so the two read as one instrument
              // rather than a chip beside a stripe.
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Slides under the badge's straight edge only: shorter
                  // and the track's cells peek through the chamfer notches,
                  // which read as a glitch, not an overlap.
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: _RoundGauge(
                      round: sim.financeRound,
                      target: sim.roundProgress,
                    ),
                  ),
                  // The reading with the currency's own face after it --
                  // composed here rather than through the bar's reading,
                  // which speaks text alone.
                  Positioned(
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, 0.8),
                          // Both numbers CUMULATIVE: the eye compares this
                          // pair against the lifetime turnover anyway, so
                          // the pair is written on that same scale.
                          child: Text(
                            '${sim.creditsEarned.value}'
                            ' / ${sim.roundFloor(sim.financeRound + 1)}',
                            style: AppText.display(
                              8.5,
                              weight: FontWeight.w700,
                              color: Palette.text,
                              height: 1,
                            ).copyWith(shadows: AppText.halo),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const ResourceIcon(ResourceId.credits, size: 11),
                      ],
                    ),
                  ),
                  _RoundBadge(game: game, onTap: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How long a mode has been held, ticking once a second.
///
/// Driven by a plain [Timer], not a Ticker: both overlays live where
/// TickerMode is off or the scene is meant to be still, and a frame-rate
/// clock for a once-a-second digit would be waste anyway.
class _SinceClock extends StatefulWidget {
  const _SinceClock({
    required this.since,
    required this.prefix,
    required this.color,
  });

  final DateTime since;
  final String prefix;
  final Color color;

  @override
  State<_SinceClock> createState() => _SinceClockState();
}

class _SinceClockState extends State<_SinceClock> {
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    _beat = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  static String _clock(Duration span) {
    String two(int value) => value.toString().padLeft(2, '0');
    if (span.inHours > 0) {
      return '${span.inHours}:${two(span.inMinutes % 60)}:'
          '${two(span.inSeconds % 60)}';
    }
    return '${two(span.inMinutes)}:${two(span.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final held = DateTime.now().difference(widget.since);
    return Text(
      '${widget.prefix} ${_clock(held < Duration.zero ? Duration.zero : held)}',
      style: AppText.display(
        13,
        weight: FontWeight.w600,
        color: widget.color,
        shadows: true,
      ),
    );
  }
}

/// The dark room the game keeps mining in.
///
/// Near-black on purpose -- dark pixels are what an OLED pays nothing for --
/// with a handful of live numbers, redrawn only when a tick lands. No ticker
/// runs anywhere on screen; the per-second cost is the text below.
class _BackgroundOverlay extends StatelessWidget {
  const _BackgroundOverlay({required this.game, required this.onExit});

  final Game game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudTap(
      onTap: onExit,
      // Tap-anywhere surfaces keep the hand but not the film: a wash the
      // size of the screen reads as a glitch, not an affordance.
      wash: false,
      child: ColoredBox(
        color: const Color(0xFF03050A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ti.moon, size: 26, color: Color(0x597FD9C4)),
            const SizedBox(height: 14),
            Text(
              'ФОНОВИЙ РЕЖИМ',
              style: AppText.body(
                11,
                weight: FontWeight.w800,
                color: const Color(0x8CA0ADC1),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '${sim.layer.value + 1} м',
              style: AppText.display(
                34,
                weight: FontWeight.w700,
                color: const Color(0xB3FFD782),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DimResource(
                  id: ResourceId.regolith,
                  value: '${sim.regolith.value}',
                ),
                const SizedBox(width: 18),
                _DimResource(
                  id: ResourceId.crystals,
                  value: '${sim.crystals.value}',
                ),
                const SizedBox(width: 18),
                _DimResource(
                  id: ResourceId.quantonium,
                  value: '${sim.quantonium.value}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SinceClock(
              since: game.backgroundAt ?? DateTime.now(),
              prefix: 'у фоні',
              color: const Color(0x8CA0ADC1),
            ),
            const SizedBox(height: 18),
            Text(
              'симуляція працює · рендер вимкнено',
              style: AppText.body(9.5, color: const Color(0x667C8A9C)),
            ),
            const SizedBox(height: 4),
            Text(
              'торкнись, щоб повернутись',
              style: AppText.body(9.5, color: const Color(0x667C8A9C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimResource extends StatelessWidget {
  const _DimResource({required this.id, required this.value});

  final ResourceId id;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceIcon(id, size: 17, colour: const Color(0x66A0ADC1)),
        const SizedBox(width: 5),
        Text(
          value,
          style: AppText.display(
            13,
            weight: FontWeight.w600,
            color: const Color(0x99D6DDE9),
          ),
        ),
      ],
    );
  }
}

/// The frozen game, said out loud.
///
/// Glass, not a wall: TickerMode above has already frozen every animation in
/// the scene, so the stillness underneath IS the message and deserves to be
/// seen. The tint only says "input goes to me now".
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.since, required this.onResume});

  final DateTime since;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onResume,
      wash: false,
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
            const SizedBox(height: 8),
            _SinceClock(
              since: since,
              prefix: 'на паузі',
              color: Palette.textDim,
            ),
            const SizedBox(height: 8),
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

/// The clock has been wound back past what the save already lived.
///
/// Unclosable on purpose: the save's last observed moment is in the
/// player's future, and the simulation refuses to run until reality
/// catches up. The one door out is loading a save that was not played
/// against a wound clock.
class _BreachOverlay extends StatefulWidget {
  const _BreachOverlay({required this.game, required this.untilMs});

  final Game game;
  final int untilMs;

  @override
  State<_BreachOverlay> createState() => _BreachOverlayState();
}

class _BreachOverlayState extends State<_BreachOverlay> {
  bool _saves = false;

  String _countdown() {
    final left = widget.untilMs - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return '0:00:00';
    final s = (left / 1000).ceil();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '$h:${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }

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
            onClose: () => setState(() => _saves = false),
          ),
      ],
    );
  }
}

/// The strip's round gauge, chasing its own money.
///
/// New income lands in a pale lane INSTANTLY; the credit-green fill then
/// animates up to it. Two frames of truth on one track: where you are, and
/// what just arrived -- the chase is what makes a sale feel banked.
class _RoundGauge extends StatefulWidget {
  const _RoundGauge({required this.round, required this.target});

  /// The round the bar is filling. A change means the ladder rolled over:
  /// the fill snaps to zero and climbs the new rung rather than easing
  /// backwards through it.
  final int round;

  final double target;

  @override
  State<_RoundGauge> createState() => _RoundGaugeState();
}

class _RoundGaugeState extends State<_RoundGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chase;

  @override
  void initState() {
    super.initState();
    _chase = AnimationController(vsync: this, value: widget.target);
  }

  @override
  void didUpdateWidget(_RoundGauge old) {
    super.didUpdateWidget(old);
    if (widget.round != old.round) _chase.value = 0;
    if (_chase.value != widget.target) {
      // The duration is EXPLICIT because animateTo without one scales the
      // controller's duration by the remaining distance -- a small sale got
      // a chase of eighty milliseconds and read as a plain jump. Measured,
      // not guessed: the diagnostics log said "done" 83 ms after the start.
      _chase.animateTo(
        widget.target,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _chase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A POUR, not cells: money is continuous, and a cell lane swallowed any
    // arrival smaller than one cell -- the chase was real and invisible.
    // Two gauges on one track: the pale one snaps to what just arrived, the
    // credit-green one rides the controller frame by frame underneath it.
    return SizedBox(
      height: 14,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Near-white, not a lighter green: the two lanes sit on a
          // 14-px strip, and two light greens read as one -- caught on a
          // frame grab, present and invisible at once.
          Gauge(
            fraction: widget.target,
            height: 14,
            radius: 0,
            fill: Palette.text,
          ),
          Gauge.live(
            value: _chase,
            height: 14,
            radius: 0,
            track: const Color(0x00000000),
            fill: Palette.credit,
          ),
        ],
      ),
    );
  }
}

/// The financing round, worn on the strip: the level the turnover bought,
/// and the dot when a tranche waits to be poured.
class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.game, required this.onTap});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final free = sim.tranchesFree;
    return HudTap(
      onTap: onTap,
      corners: HudCorners.centred,
      cut: 6,
      child: HudPlate(
        cut: 6,
        fill: Palette.goldWell,
        edge: Palette.amber,
        padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
        // A floor under the width so the bar's fixed underlap always meets
        // the straight edge, whatever the round number's length.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Р${sim.financeRound}',
                style: AppText.display(
                  13,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                  height: 1.1,
                ),
              ),
              if (free > 0) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Palette.tech,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.page, width: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
        child: _Dotted(
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
    return _Dotted(
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.screen});

  final GameScreen screen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(screen.icon, size: 30),
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
