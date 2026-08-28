import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'game_icons.dart';

/// The four things the player can be doing.
///
/// Two levels rather than one flat row: the game has more screens than a
/// phone-width bar can hold, and grouping them means a new screen joins a
/// section instead of shrinking every tab.
enum NavSection {
  extraction('Видобуток', Ic.extraction),
  production('Виробництво', Ic.production),
  research('Дослідження', Ic.research),
  console('Консоль', Ic.console);

  const NavSection(this.label, this.icon);

  final String label;

  /// The game's own glyph, not a font codepoint: an asset the nav tints.
  final String icon;

  /// The console opens as a panel of cards rather than a strip of chips: its
  /// entries are places you go, do one thing and come back from, not places
  /// you move between while playing.
  bool get opensAsPanel => this == NavSection.console;

  Iterable<GameScreen> get screens =>
      GameScreen.values.where((screen) => screen.section == this);

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
  planets(NavSection.extraction, 'Планети', Ic.planets),

  craft(NavSection.production, 'Крафт', Ic.craft),
  building(NavSection.production, 'Будівництво', Ic.building),
  lab(NavSection.production, 'Лабораторія', Ic.lab),

  tree(NavSection.research, 'Дерево', Ic.tree),
  avatar(NavSection.research, 'Аватар', Ic.avatar),
  samples(NavSection.research, 'Зразки', Ic.samples),

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
  GameScreen.upgrades => game.sim.canBuyDrill || game.sim.canBuyPowerUpgrade,
  GameScreen.strikes => ArmPart.values.any(
    (part) => game.sim.canUpgrade(part) || game.sim.canEvolve(part),
  ),
  _ => false,
};

bool sectionNeedsAttention(NavSection section, Game game) =>
    section.screens.any((screen) => screenNeedsAttention(screen, game));
