import 'package:flutter/widgets.dart';

import '../game.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'cubes_icon.dart';
import 'tokens.dart';

/// The two trees, and what tells them apart.
///
/// One screen with a row here rather than two widgets: they are the same
/// object at two levels -- a graph of nodes bought with what a prestige pays
/// -- and the only honest differences are the currency, the colour and the
/// name. A second file would have made them drift.
enum TreeKind {
  /// Bought with OLAP cubes, banked by a Restart. Tunes what the runs inside
  /// this cycle get.
  simulation('olap-куби', Ic.tree, Palette.gold),

  /// Bought with collapse points, one per rack taken. A level below, so it
  /// keeps the alarm colour the collapse act is written in.
  firmware('патчі', Ic.collapse, Palette.alarm);

  const TreeKind(this.currency, this.icon, this.accent);

  final String currency;
  final String icon;
  final Color accent;
}

/// A tree of nodes, bought with what a prestige pays.
class TreeScreen extends StatelessWidget {
  const TreeScreen({required this.kind, required this.game, super.key});

  final TreeKind kind;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The wallet at the top of the thing that spends it: a tree is a
          // shop, and a shop says what the player is holding before it says
          // what it sells.
          // Half the width, on the reading side. A wallet stretched across
          // the whole shelf reads as a shelf with one thing on it.
          Row(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                child: HudStat(
                  label: kind.currency,
                  align: CrossAxisAlignment.end,
                  value: switch (kind) {
                    TreeKind.simulation => '${sim.dataWallet.value}',
                    TreeKind.firmware => '${sim.collapses.value}',
                  },
                  size: 20,
                  accent: kind.accent,
                  colour: kind.accent,
                  labelColour: kind.accent,
                  unit: switch (kind) {
                    TreeKind.simulation => const CubesIcon(size: 20),
                    TreeKind.firmware => GameIcon(
                      Ic.collapse,
                      size: 18,
                      colour: kind.accent,
                    ),
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(kind.icon, size: 30, colour: kind.accent),
                  const SizedBox(height: 10),
                  Text('ВУЗЛИ', style: AppText.eyebrow()),
                  const SizedBox(height: 6),
                  Text(
                    'наступний прохід',
                    style: AppText.body(12, color: Palette.textFaint),
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
