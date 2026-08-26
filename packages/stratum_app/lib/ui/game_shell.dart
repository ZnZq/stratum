import 'package:flutter/widgets.dart';

import '../game.dart';
import 'drill_screen.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

enum GameTab { drill, tree, planets, craft, avatar }

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
  GameTab _tab = GameTab.drill;

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
                  builder: (context, _) => Column(
                    children: [
                      _ResourceBar(game: _game),
                      Expanded(
                        child: switch (_tab) {
                          GameTab.drill => DrillScreen(game: _game),
                          _ => _Placeholder(tab: _tab),
                        },
                      ),
                      _TabBar(
                        active: _tab,
                        onSelect: (tab) => setState(() => _tab = tab),
                      ),
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
  const _ResourceBar({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Palette.bar,
        border: Border(bottom: BorderSide(color: Palette.lineBar)),
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
                    value: '${sim.ore.value}'),
                const SizedBox(width: 13),
                _Resource(
                    icon: Ti.atom2,
                    colour: Palette.quantonium,
                    value: '${sim.quantonium.value}'),
                const SizedBox(width: 13),
                _Resource(
                    icon: Ti.diamond,
                    colour: Palette.sample,
                    value: '${sim.samples.value}'),
                const SizedBox(width: 13),
                _Resource(
                    icon: Ti.cpu,
                    colour: Palette.compute,
                    value: '${sim.backgroundCompute.value}'),
              ],
            ),
          ),
          _Resource(
              icon: Ti.capsule,
              colour: Palette.gold,
              value: '${sim.capsules.value}'),
        ],
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
        Text(value,
            style: AppText.display(12.5,
                weight: FontWeight.w700, color: colour)),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onSelect});

  final GameTab active;
  final ValueChanged<GameTab> onSelect;

  static const List<(GameTab, IconData, String)> _tabs = [
    (GameTab.drill, Ti.arrowBarDown, 'Бур'),
    (GameTab.tree, Ti.binaryTree, 'Дерево'),
    (GameTab.planets, Ti.planet, 'Планети'),
    (GameTab.craft, Ti.tools, 'Крафт'),
    (GameTab.avatar, Ti.userHexagon, 'Аватар'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Palette.bar,
        border: Border(top: BorderSide(color: Palette.lineBar)),
      ),
      child: Row(
        children: [
          for (final (tab, icon, label) in _tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(tab),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: tab == active
                            ? Palette.gold
                            : Palette.textFaint),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: AppText.body(9.5,
                          color: tab == active
                              ? Palette.gold
                              : Palette.textFaint),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tab});

  final GameTab tab;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(switch (tab) {
            GameTab.tree => 'дерево симуляції',
            GameTab.planets => 'планети',
            GameTab.craft => 'крафт',
            GameTab.avatar => 'аватар',
            GameTab.drill => '',
          }, style: AppText.eyebrow()),
          const SizedBox(height: 6),
          Text('наступний прохід',
              style: AppText.body(12, color: Palette.textFaint)),
        ],
      ),
    );
  }
}
