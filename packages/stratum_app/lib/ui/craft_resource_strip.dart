import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// The bench's till: credits, and ONLY what the current jobs eat -- the
/// union of the assigned recipes' inputs, so every figure on the strip is
/// one somebody's line is draining right now. An input a starving line
/// cannot pay for turns amber. No jobs, no figures: credits and the
/// warehouse door alone. Checking stock must never cost a navigation.
/// Collapsible: folded, only the till row stays.
class CraftResourceStrip extends StatefulWidget {
  const CraftResourceStrip({
    required this.game,
    required this.onWarehouse,
    super.key,
  });

  final Game game;
  final VoidCallback onWarehouse;

  @override
  State<CraftResourceStrip> createState() => _CraftResourceStripState();
}

class _CraftResourceStripState extends State<CraftResourceStrip> {
  bool _open = true;

  Game get game => widget.game;

  VoidCallback get onWarehouse => widget.onWarehouse;

  /// The eaten-input chips in balanced rows: ceil(n/4) rows, equal
  /// column count throughout, missing cells left empty so the columns
  /// stand still whatever the figures do.
  List<Widget> _chipRows(
    PrototypeSimulation sim,
    List<ResourceId> shown,
    Set<ResourceId> short,
  ) {
    final rowCount = (shown.length / 4).ceil();
    final columns = (shown.length / rowCount).ceil();
    return [
      for (var r = 0; r < rowCount; r++) ...[
        if (r > 0) const SizedBox(height: 4),
        Row(
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: 8),
              Expanded(
                child: r * columns + c < shown.length
                    ? _chip(sim, shown[r * columns + c], short)
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  Widget _chip(PrototypeSimulation sim, ResourceId id, Set<ResourceId> short) {
    return Row(
      children: [
        ResourceIcon(id, size: 11),
        const SizedBox(width: 3),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${sim.stock.amount(id)}',
              style: AppText.display(
                9.5,
                weight: FontWeight.w600,
                color: short.contains(id) ? Palette.amber : Palette.textDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    // What the bench is eating: every assigned line's inputs, deduped,
    // in the registry's order. A starving line marks the inputs it
    // cannot pay for.
    final eaten = <ResourceId>{};
    final short = <ResourceId>{};
    for (final line in sim.craftLines) {
      final row = craftRecipeOf(line.recipe.value);
      if (row == null || line.done) continue;
      final scale = math.pow(craftCostStep, line.tier.value).toDouble();
      for (final entry in row.inputs.entries) {
        eaten.add(entry.key);
        if (line.starving.value &&
            !sim.stock.amount(entry.key).gteWithTolerance(
              BigDouble.fromNum(entry.value * scale),
            )) {
          short.add(entry.key);
        }
      }
    }
    final shown = eaten.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return HudPlate(
      cut: 7,
      fill: Palette.shell.withValues(alpha: 0.7),
      edge: Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ResourceIcon(ResourceId.credits, size: 12),
              const SizedBox(width: 4),
              Text(
                '${sim.stock.amount(ResourceId.credits)}',
                style: AppText.display(
                  10.5,
                  weight: FontWeight.w700,
                  color: Palette.credit,
                ),
              ),
              const Spacer(),
              if (shown.isNotEmpty) ...[
                HudTap(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Icon(
                      _open ? Ti.chevronUp : Ti.chevronDown,
                      size: 11,
                      color: Palette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              HudButton(
                onTap: onWarehouse,
                accent: Palette.textMuted,
                padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
                child: Text(
                  'СКЛАД',
                  style: AppText.body(
                    8,
                    weight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          // Any number of lines eating any number of inputs: FIXED equal
          // columns, at most four to a row, split evenly across rows --
          // a Wrap re-flowed with every digit the figures grew, and six
          // over two read as a pile, not a panel.
          if (_open && shown.isNotEmpty) ...[
            const SizedBox(height: 5),
            ..._chipRows(sim, shown, short),
          ],
        ],
      ),
    );
  }
}
