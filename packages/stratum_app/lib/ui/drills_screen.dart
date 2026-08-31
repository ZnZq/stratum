import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'drill_detail.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'hud.dart';
import 'tokens.dart';
import 'resource_icon.dart';

/// Every drill the player owns, and the ladder of the ones still to come.
///
/// A list rather than a screen per drill behind a nav row: the drills are
/// compared against each other -- which one is worth the next payment -- and
/// a comparison you have to leave the screen to make is not one. Tapping a
/// drill opens its own screen; the list is where you decide which.
class DrillsScreen extends StatefulWidget {
  const DrillsScreen({required this.game, super.key});

  final Game game;

  @override
  State<DrillsScreen> createState() => _DrillsScreenState();
}

class _DrillsScreenState extends State<DrillsScreen> {
  /// The drill whose own screen is open, if any.
  DrillId? _open;

  @override
  Widget build(BuildContext context) {
    if (_open case final id?) {
      return DrillDetail(
        game: widget.game,
        id: id,
        onBack: () => setState(() => _open = null),
      );
    }

    final sim = widget.game.sim;
    return ColoredBox(
      color: Palette.scene,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Stat(
              label: 'ваші бури',
              rule: true,
              trailing: Text(
                '1 / ${PrototypeSimulation.drillTable.length}',
                style: AppText.display(9, color: Palette.textFaint),
              ),
            ),
          ),
          for (final row in PrototypeSimulation.drillTable) ...[
            const HudRule(),
            _DrillRow(
              game: widget.game,
              row: row,
              owned: sim.drillOwned(row.id),
              onOpen: sim.drillOwned(row.id)
                  ? () => setState(() => _open = row.id)
                  : null,
            ),
          ],
          const HudRule(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text(
              'решта відкривається деревом симуляції',
              style: AppText.body(9.5, color: Palette.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

/// One drill, said in the four numbers you would compare drills by.
class _DrillRow extends StatelessWidget {
  const _DrillRow({
    required this.game,
    required this.row,
    required this.owned,
    required this.onOpen,
  });

  final Game game;
  final DrillRow row;
  final bool owned;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final style = resourceStyles[row.mines]!;

    return HudTap(
      onTap: onOpen,
      child: Opacity(
        opacity: owned ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: owned ? Palette.goldWell : Palette.shell,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: owned ? Palette.amber : Palette.lineBar,
                  ),
                ),
                child: ResourceIcon(row.mines, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              12,
                              weight: FontWeight.w700,
                              color: style.colour,
                            ),
                          ),
                        ),
                        if (!owned)
                          Text(
                            'дерево симуляції',
                            style: AppText.body(9, color: Palette.textFaint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (owned)
                      Row(
                        children: [
                          _Fact(
                            label: 'r',
                            value: '${sim.drillRadius(row.id).round()} м',
                          ),
                          _Fact(
                            label: 'цикл',
                            value:
                                '${sim.drillInterval(row.id).toStringAsFixed(2)} с',
                          ),
                          _Fact(
                            label: 'крит',
                            value:
                                '${(sim.drillCritChance(row.id) * 100).toStringAsFixed(1)}%',
                          ),
                          _Fact(
                            label: 'ехо',
                            value:
                                '${(sim.drillEchoChance(row.id) * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      )
                    else
                      Text(
                        'видобуває свій ресурс власним циклом',
                        style: AppText.body(9.5, color: Palette.textFaint),
                      ),
                  ],
                ),
              ),
              if (owned) ...[
                const SizedBox(width: 8),
                Text('›', style: AppText.display(16, color: Palette.textFaint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the facts a drill is compared by: the name small, the figure plain.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.body(8.5, color: Palette.textFaint)),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppText.display(
              9.5,
              weight: FontWeight.w600,
              color: Palette.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
