import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'game_icons.dart';

/// The two worlds the player moves between (owner, 2026-09-03).
///
/// The simulation is where the AI works: the mine, the benches, the
/// research. The centre is where it grows: the acts that end a simulation,
/// the trees they pay for, the numbers that say when. Each has its own row
/// of sections; a button on either home screen crosses to the other.
enum GameWorld {
  simulation('STRATUM'),
  centre('ЦЕНТР РОЗВИТКУ ШІ');

  const GameWorld(this.title);

  /// What the world's home screen is named over its field.
  final String title;

  GameWorld get other => switch (this) {
    GameWorld.simulation => GameWorld.centre,
    GameWorld.centre => GameWorld.simulation,
  };

  /// What the crossing button reads on THIS world's home screen: it names
  /// where it leads, not where it stands.
  String get crossing => switch (this) {
    GameWorld.simulation => 'ЦЕНТР РОЗВИТКУ ШІ',
    GameWorld.centre => 'ДО СИМУЛЯЦІЇ',
  };
}

/// The things the player can be doing, grouped by world.
///
/// Two levels rather than one flat row: the game has more screens than a
/// phone-width bar can hold, and grouping them means a new screen joins a
/// section instead of shrinking every tab. A section with a single screen
/// shows no strip: the centre's sections each ARE their screen.
enum NavSection {
  extraction('Видобуток', Ic.extraction, GameWorld.simulation),
  production('Виробництво', Ic.production, GameWorld.simulation),
  research('Дослідження', Ic.research, GameWorld.simulation),

  /// Where a simulation is ended: both acts, and the wall of servers
  /// that says how close the next overload is.
  acts('Симуляція', Ic.datacentre, GameWorld.centre),

  /// Bought with parameters. Named short: the world already says whose
  /// tree it is.
  tree('Дерево', Ic.tree, GameWorld.centre),

  /// Bought with patches. A level below the tree: it rewrites what every
  /// future cycle runs ON.
  firmware('Прошивка', Ic.collapse, GameWorld.centre),

  /// The run's live numbers -- rates, forecasts, fragmentation.
  analytics('Аналітика', Ic.stats, GameWorld.centre),

  /// The game's own console, in every world: it is the service hatch of
  /// the app, not of either place.
  console('Консоль', Ic.console, null);

  const NavSection(this.label, this.icon, this.world);

  final String label;

  /// The game's own glyph, not a font codepoint: an asset the nav tints.
  final String icon;

  /// The world whose row carries this section; null for every world.
  final GameWorld? world;

  bool inWorld(GameWorld world) => this.world == null || this.world == world;

  static Iterable<NavSection> of(GameWorld world) =>
      values.where((section) => section.inWorld(world));

  /// The console opens as a panel of cards rather than a strip of chips: its
  /// entries are places you go, do one thing and come back from, not places
  /// you move between while playing.
  bool get opensAsPanel => this == NavSection.console;

  Iterable<GameScreen> get screens =>
      GameScreen.values.where((screen) => screen.section == this);

  /// Whether the section is its one screen, and so needs no strip.
  bool get single => screens.length == 1;

  /// Where tapping the section lands before the player has picked anything.
  GameScreen get landing => screens.first;
}

/// Every screen, and the section it belongs to.
///
/// One list rather than a table per section: the order here is the order the
/// bar shows, and a screen cannot end up in two places or in none.
enum GameScreen {
  /// The mine itself: dig by hand, watch the rigs work.
  drill(NavSection.extraction, 'Шахта', Ic.mine),

  /// The arm itself and the three parts of it that upgrade: bit, drive,
  /// supply.
  strikes(NavSection.extraction, 'Маніпулятор', Ic.arm),

  /// Every drill the player owns, and where they are upgraded.
  upgrades(NavSection.extraction, 'Бури', Ic.drills),

  /// What runs on the player's behalf: bought here, tuned in its own
  /// window.
  automation(NavSection.extraction, 'Автоматизація', Ic.automation),
  planets(NavSection.extraction, 'Планети', Ic.planets),

  /// Selling what the shaft brings up. First in the section because it is
  /// the first thing a player does with a pile of regolith -- turn it into
  /// credits and buy the drill that digs the next pile.
  trade(NavSection.production, 'Торгівля', Ic.trade),

  craft(NavSection.production, 'Крафт', Ic.craft),
  building(NavSection.production, 'Будівництво', Ic.building),
  lab(NavSection.production, 'Лабораторія', Ic.lab),

  /// The passive copier of crafted resources -- what closes the big
  /// volumes the constructions will ask for.
  replicator(NavSection.production, 'Реплікатор', Ic.replicator),

  /// Everything the player owns, on shelves. Last in the section: the pile
  /// is where the chain ENDS UP, and the tabs before it are what happens
  /// to it on the way.
  warehouse(NavSection.production, 'Склад', Ic.warehouse),

  avatar(NavSection.research, 'Аватар', Ic.avatar),
  samples(NavSection.research, 'Зразки', Ic.samples),

  /// Where a simulation is ended: both acts, and the wall of servers that
  /// says how close the next overload is.
  simulation(NavSection.acts, 'Симуляція', Ic.datacentre),

  /// Bought with parameters, trained by a Restart.
  tree(NavSection.tree, 'Дерево', Ic.tree),

  /// Bought with patches. A level below the tree: it rewrites what every
  /// future cycle runs ON.
  firmware(NavSection.firmware, 'Прошивка', Ic.collapse),

  /// The run's live numbers -- rates, forecasts, fragmentation. Not the
  /// console's statistics, which are lifetime totals: this one is about
  /// now.
  analytics(NavSection.analytics, 'Аналітика', Ic.stats),

  settings(
    NavSection.console,
    'Налаштування',
    Ic.settings,
    note: 'звук, мова, інтерфейс',
  ),
  daily(NavSection.console, 'Щоденні', Ic.daily, note: 'нагорода за вхід'),
  achievements(
    NavSection.console,
    'Досягнення',
    Ic.achievements,
    note: 'віхи прогресу',
  ),
  stats(NavSection.console, 'Статистика', Ic.stats, note: 'числа за весь час'),
  account(
    NavSection.console,
    'Акаунт',
    Ic.account,
    note: 'профіль і синхронізація',
  ),

  /// Opens the save panel over whatever is showing rather than replacing it,
  /// so a save is never made from a screen the player did not mean to be on.
  saves(
    NavSection.console,
    'Збереження',
    Ic.saves,
    note: 'слоти й автозбереження',
  );

  const GameScreen(this.section, this.label, this.icon, {this.note = ''});

  final NavSection section;
  final String label;
  final String icon;

  /// One line on what the screen is for. Only the console shows it, because
  /// only the console gives its entries room to be read.
  final String note;

  bool get isOverlay => this == GameScreen.saves;
}

/// Whether a screen has something the player can act on right now.
///
/// This is what the dot on a tab is for, and in an idle game it is not
/// decoration: the player must not have to open a screen to find out whether
/// it was worth opening. Screens with nothing to do yet answer false rather
/// than being left out, so wiring one up later is a case here and nothing
/// else.
bool screenNeedsAttention(GameScreen screen, Game game) => switch (screen) {
  GameScreen.trade => game.hasUnseenRequests,
  GameScreen.simulation =>
    game.sim.pendingCollapses(DateTime.now().millisecondsSinceEpoch) > 0,
  GameScreen.upgrades => game.hasNewDrillUpgrades,
  GameScreen.automation => game.hasNewAutomation,
  GameScreen.strikes => ArmPart.values.any(
    (part) => game.sim.canUpgrade(part) || game.sim.canEvolve(part),
  ),
  _ => false,
};

bool sectionNeedsAttention(NavSection section, Game game) =>
    section.screens.any((screen) => screenNeedsAttention(screen, game));

/// Whether anything in [world]'s own sections wants the player: what the
/// crossing button on the other world's home screen carries a dot for.
bool worldNeedsAttention(GameWorld world, Game game) => NavSection.values.any(
  (section) => section.world == world && sectionNeedsAttention(section, game),
);
