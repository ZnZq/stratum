import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'drill_diagram.dart';
import 'dissolve.dart';
import 'track_row.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'tokens.dart';
import 'track_header.dart';

/// One drill: the machine at work, what it is worth, and its three tracks.
///
/// Laid out like the manipulator, because it is the same kind of thing: a
/// piece of hardware you watch and pay into. The band runs edge to edge and
/// the panel below fades in over its foot, so the screen is one surface
/// rather than a tray of boxes.
class DrillDetail extends StatefulWidget {
  const DrillDetail({
    required this.game,
    required this.id,
    required this.onBack,
    super.key,
  });

  final Game game;
  final DrillId id;
  final VoidCallback onBack;

  @override
  State<DrillDetail> createState() => _DrillDetailState();
}

class _DrillDetailState extends State<DrillDetail> {
  /// How many levels one tap buys.
  int _batch = 1;

  static const double _band = 116;
  static const double _dissolve = 24;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final sim = game.sim;
    final row = PrototypeSimulation.rowFor(widget.id);

    return ColoredBox(
      color: Palette.scene,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DrillDiagram(game: game, id: widget.id, height: _band),
          ),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: _band - _dissolve),
                const Dissolve(height: _dissolve),
                Expanded(child: _panel(game, sim, row)),
              ],
            ),
          ),
          // The way back, over the band where it costs no layout.
          Positioned(
            left: 6,
            top: 6,
            child: HudTap(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 11, 6),
                decoration: BoxDecoration(
                  color: const Color(0xB3141B26),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Palette.lineBar),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '‹',
                      style: AppText.display(14, color: Palette.textMuted),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'бури',
                      style: AppText.body(9.5, color: Palette.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Game game, PrototypeSimulation sim, DrillRow row) {
    final style = resourceStyles[row.mines]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Stat(
                  label: row.label,
                  labelColour: style.colour,
                  value: '${sim.drillArea(widget.id).round()} м²',
                  size: 13,
                  colour: style.colour,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stat(
                  label: 'цикл',
                  value: '${sim.drillInterval(widget.id).toStringAsFixed(2)} с',
                  size: 13,
                  colour: Palette.tech,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stat(
                  label: 'крит',
                  value:
                      '${(sim.drillCritChance(widget.id) * 100).toStringAsFixed(1)}%',
                  size: 13,
                  colour: Palette.gold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        TrackHeader(
          label: 'ПРОКАЧКА БУРА',
          batch: _batch,
          onPick: (value) => setState(() => _batch = value),
        ),
        const SizedBox(height: 8),
        const HudRule(),
        // Intrinsic height, not an equal share of what is left: a track row
        // has nothing inside it that could use the slack, and three rows
        // stretched to fill the screen read as three empty boxes.
        for (final part in DrillPart.values) ...[
          TrackRow(game: game, id: widget.id, part: part, batch: _batch),
          const HudRule(),
        ],
      ],
    );
  }
}
