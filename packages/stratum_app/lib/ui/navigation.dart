import 'package:flutter/widgets.dart';

import '../game.dart';
import 'tabler_icons.dart';

/// The four things the player can be doing.
///
/// Two levels rather than one flat row: the game has more screens than a
/// phone-width bar can hold, and grouping them means a new screen joins a
/// section instead of shrinking every tab.
enum NavSection {
  extraction('Видобуток', Ti.pick),
  production('Виробництво', Ti.factory),
  research('Дослідження', Ti.telescope),
  console('Консоль', Ti.terminal2);

  const NavSection(this.label, this.icon);

  final String label;
  final IconData icon;

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
  drill(NavSection.extraction, 'Бур', Ti.arrowBarDown),
  upgrades(NavSection.extraction, 'Покращення', Ti.adjustments),
  planets(NavSection.extraction, 'Планети', Ti.planet),

  craft(NavSection.production, 'Крафт', Ti.tools),
  building(NavSection.production, 'Будівництво', Ti.crane),
  lab(NavSection.production, 'Лабораторія', Ti.microscope),

  tree(NavSection.research, 'Дерево', Ti.binaryTree),
  avatar(NavSection.research, 'Аватар', Ti.userHexagon),
  samples(NavSection.research, 'Зразки', Ti.flask2),

  settings(
    NavSection.console,
    'Налаштування',
    Ti.settings2,
    note: 'звук, мова, інтерфейс',
  ),
  daily(NavSection.console, 'Щоденні', Ti.gift, note: 'нагорода за вхід'),
  achievements(
    NavSection.console,
    'Досягнення',
    Ti.trophy,
    note: 'віхи прогресу',
  ),
  stats(
    NavSection.console,
    'Статистика',
    Ti.chartLine,
    note: 'числа за весь час',
  ),
  account(
    NavSection.console,
    'Акаунт',
    Ti.userCircle,
    note: 'профіль і синхронізація',
  ),

  /// Opens the save panel over whatever is showing rather than replacing it,
  /// so a save is never made from a screen the player did not mean to be on.
  saves(
    NavSection.console,
    'Збереження',
    Ti.deviceFloppy,
    note: 'слоти й автозбереження',
  );

  const GameScreen(this.section, this.label, this.icon, {this.note = ''});

  final NavSection section;
  final String label;
  final IconData icon;

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
  _ => false,
};

bool sectionNeedsAttention(NavSection section, Game game) =>
    section.screens.any((screen) => screenNeedsAttention(screen, game));
