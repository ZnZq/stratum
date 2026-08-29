import 'package:flutter/widgets.dart';

import '../game.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'tokens.dart';

/// The two trees, and what tells them apart.
///
/// One sheet with a row here rather than two widgets: they are the same
/// object at two levels -- a graph of nodes bought with what a prestige pays
/// -- and the only honest differences are the currency, the colour and the
/// name. A second file would have made them drift.
enum TreeKind {
  /// Bought with OLAP cubes, banked by a Restart. Tunes what the runs inside
  /// this cycle get.
  simulation('ДЕРЕВО СИМУЛЯЦІЇ', Palette.gold),

  /// Bought with collapse points, one per rack taken. A level below: it
  /// rewrites what every future cycle runs ON, so it keeps the alarm colour
  /// the collapse act is written in.
  firmware('ПРОШИВКА', Palette.alarm);

  const TreeKind(this.title, this.accent);

  final String title;
  final Color accent;
}

/// A tree, over whatever the player was looking at.
///
/// A sheet rather than a screen: a tree is where a prestige's payout is spent,
/// and both prestige acts live on the Data Centre. Sending the player to a
/// separate tab to spend what they just banked would put a room between the
/// act and its reward, and the research section's slot is kept for something
/// the player MOVES to rather than opens.
class TreeSheet extends StatelessWidget {
  const TreeSheet({
    required this.kind,
    required this.game,
    required this.onClose,
    super.key,
  });

  final TreeKind kind;
  final Game game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return HudModal(
      icon: kind == TreeKind.simulation ? Ic.tree : Ic.collapse,
      title: kind.title,
      accent: kind.accent,
      // Full height: a tree is a graph the player pans around and compares
      // branches in, not a card to glance at. A sheet that stops halfway
      // would make every node fight for the same third of the screen.
      anchor: ModalAnchor.stretch,
      onClose: onClose,
      // The wallet beside the title: a tree is a shop, and a shop says what
      // the player is holding before it says what it sells.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (kind) {
            TreeKind.simulation => const CubesIcon(size: 14),
            TreeKind.firmware => GameIcon(
              Ic.collapse,
              size: 14,
              colour: kind.accent,
            ),
          },
          const SizedBox(width: 4),
          Text(
            switch (kind) {
              TreeKind.simulation => '${sim.dataWallet.value}',
              TreeKind.firmware => '${sim.collapses.value}',
            },
            style: AppText.display(
              13,
              weight: FontWeight.w700,
              color: kind.accent,
            ),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(
              kind == TreeKind.simulation ? Ic.tree : Ic.collapse,
              size: 30,
              colour: kind.accent,
            ),
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
    );
  }
}
