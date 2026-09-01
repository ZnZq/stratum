import 'package:flutter/widgets.dart';

import '../game.dart';
import 'building/building_canvas.dart';
import 'building/building_node.dart';
import 'hud.dart';
import 'stat.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// The construction graph: buildings as tree nodes, paid in crafted
/// components, giving buffs AND openings -- the game's third tree, with a
/// material currency.
///
/// Today it is the CANVAS the nodes live on: pan, pinch, select, read.
/// The mechanics of raising a level arrive with the core's building state.
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({required this.game, super.key});

  final Game game;

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final node = _selected == null ? null : buildingNodeOf(_selected!);
    // The web runs FULL-BLEED: the screen inset would crop the field, and
    // a map that stops short of its frame reads as a card, not a place.
    // The header and the passport float OVER it.
    return Stack(
      children: [
        Positioned.fill(
          child: BuildingCanvas(
            selected: _selected,
            onSelect: (id) =>
                setState(() => _selected = _selected == id ? null : id),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: IgnorePointer(
            child: Stat(
              label: 'будівництво',
              rule: true,
              trailing: Text(
                '${buildingNodes.length} вузлів · механіка згодом',
                style: AppText.display(9, color: Palette.textFaint),
              ),
            ),
          ),
        ),
        if (node != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: SizedBox(height: 118, child: _panel(node)),
          ),
      ],
    );
  }

  Widget _panel(BuildingNode? node) {
    if (node == null) {
      return HudPlate(
        cut: 7,
        fill: Palette.well.withValues(alpha: 0.3),
        edge: Palette.lineBar,
        child: Center(
          child: Text(
            'обери вузол на полі',
            style: AppText.body(9, color: Palette.textFaint),
          ),
        ),
      );
    }
    return HudPlate(
      cut: 7,
      fill: Palette.shell.withValues(alpha: 0.96),
      edge: node.colour.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                node.label,
                style: AppText.display(
                  11,
                  weight: FontWeight.w700,
                  color: node.colour,
                ),
              ),
              const Spacer(),
              if (node.locked)
                Text(
                  'ще не відкрито',
                  style: AppText.body(8.5, color: Palette.textFaint),
                ),
              const SizedBox(width: 8),
              // Closing the passport releases the node's focus too.
              HudTap(
                onTap: () => setState(() => _selected = null),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(Ti.close, size: 11, color: Palette.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(node.note, style: AppText.body(8.5, color: Palette.textDim)),
          if (node.breed.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              node.breed,
              style: AppText.body(7.5, color: Palette.textFaint),
            ),
          ],
          if (node.simGated) ...[
            const SizedBox(height: 2),
            Text(
              'замкнено вузлом Дерева симуляції',
              style: AppText.body(
                7.5,
                color: Palette.amber.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (node.unlock != null) ...[
            const SizedBox(height: 3),
            Text(
              '⟐ відкриває: ${node.unlock}',
              style: AppText.display(
                8.5,
                color: Palette.gold.withValues(alpha: 0.9),
              ),
            ),
          ],
          const Spacer(),
          Text(
            node.requires.isEmpty
                ? 'корінь графа'
                : 'потребує: ${node.requires.map((id) => buildingNodeOf(id).label).join(' · ')}',
            style: AppText.body(7.5, color: Palette.textFaint),
          ),
        ],
      ),
    );
  }
}
