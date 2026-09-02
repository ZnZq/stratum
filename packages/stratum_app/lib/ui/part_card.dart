import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_style.dart';
import 'hud.dart';
import 'part_face.dart';
import 'tokens.dart';
import 'upgrade_row.dart';

/// One part of the arm: its face, its generation, and every buff it carries.
///
/// Nothing locked is drawn. A buff that a later generation opens simply is
/// not there yet, and appears in the list the moment the part evolves --
/// which makes every hundredth level a small surprise instead of a crossed
/// out line the player has been staring at for hours.
class PartCard extends StatelessWidget {
  const PartCard({
    required this.game,
    required this.part,
    required this.batch,
    required this.onRead,
    required this.onEvolve,
    super.key,
  });

  final Game game;
  final ArmPart part;
  final int batch;

  /// Opening the part's own sheet, which the face is the handle for.
  final VoidCallback onRead;

  /// Rebuilding the part into its next mark.
  final VoidCallback onEvolve;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final level = sim.levelOf(part).value;
    // The mark is built, not grown into, so it is its own number -- and it is
    // what the card must report, because it is what the buffs run on.
    final mark = sim.markOf(part).value;
    final ready = sim.canEvolve(part);
    final maxed = sim.atMaxLevel(part);
    final style = armPartStyles[part]!;
    final steps = batch == 0 ? sim.affordableLevels(part) : batch;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UpgradeRow(
            leading: HudTap(
              onTap: onRead,
              child: PartFace(part: part, mark: mark, lit: ready, size: 32),
            ),
            title: style.label,
            beside: _MarkTag(generation: mark),
            besideGap: 6,
            level: level,
            levelLit: ready || maxed,
            detail: _GenerationTrack(generation: mark),
            detailGap: 5,
            capped: maxed,
            cost: '${game.sim.upgradeCost(part)}',
            enabled: game.sim.canUpgrade(part) && steps > 0,
            onBuy: () => game.upgradeArm(part, levels: steps),
          ),
          const SizedBox(height: 6),
          // The road to the next mark, on its own line where it has room --
          // and once the road is walked, the line becomes the act itself.
          if (ready)
            _EvolveButton(onTap: onEvolve)
          else
            _MarkProgress(part: part, sim: sim, mark: mark, level: level),
          const SizedBox(height: 7),
          // The one thing allowed to shrink. The card keeps its width and its
          // share of the height; when a mark opens more buffs than there is
          // room for, the TYPE gives -- not the layout. A FittedBox would
          // scale the block on both axes, and the totals would stop reaching
          // the card's right edge, which reads as a bug rather than as a
          // crowded list.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rows = buffsOf(part, mark);
                final wanted = rows.length * _BuffRow.naturalHeight;
                final fit = wanted <= 0
                    ? 1.0
                    : (constraints.maxHeight / wanted).clamp(0.68, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final buff in rows)
                      _BuffRow(buff: buff, sim: sim, scale: fit),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkTag extends StatelessWidget {
  const _MarkTag({required this.generation});

  final int generation;

  static const List<String> _marks = [
    'Mk I',
    'Mk II',
    'Mk III',
    'Mk IV',
    'Mk V',
  ];

  @override
  Widget build(BuildContext context) {
    final opened = generation > 0;
    return HudPlate(
      cut: 4,
      fill: opened ? Palette.goldWell : Palette.card,
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      child: Text(
        _marks[generation],
        style: AppText.display(
          9,
          weight: FontWeight.w700,
          color: opened ? Palette.gold : Palette.textMuted,
        ),
      ),
    );
  }
}

class _GenerationTrack extends StatelessWidget {
  const _GenerationTrack({required this.generation});

  final int generation;

  @override
  Widget build(BuildContext context) {
    const count = PrototypeSimulation.markCount;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Expanded(
            child: SizedBox(
              height: 3,
              child: ColoredBox(
                color: switch (i) {
                  _ when i < generation => Palette.amber,
                  _ when i == generation => Palette.gold,
                  _ => Palette.lineBar,
                },
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

/// Takes the place of the price the moment a part reaches its ceiling: the
/// next hundred levels are not for sale until the piece is rebuilt.
class _EvolveButton extends StatelessWidget {
  const _EvolveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudButton(
      onTap: onTap,
      label: 'ЕВОЛЮЦІЯ',
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }
}

/// How far this mark has been walked, and which mark waits at the end.
class _MarkProgress extends StatelessWidget {
  const _MarkProgress({
    required this.part,
    required this.sim,
    required this.mark,
    required this.level,
  });

  final ArmPart part;
  final PrototypeSimulation sim;
  final int mark;
  final int level;

  @override
  Widget build(BuildContext context) {
    final span = PrototypeSimulation.markSpan(mark);
    final into = level - PrototypeSimulation.markFloor(mark);
    // A span of zero is the summit: Mk V is obtained at the very top.
    final walked = span == 0 ? 1.0 : into / span;
    // The reading counts THIS mark's hundred rather than the running
    // total: the bar measures the road to the next rebuild, so a bar a third
    // full has to read as a third, not as "137 / 200", which looks two
    // thirds done.
    // The figure rides ACROSS the cells here: the card is a stack of rows
    // with no line to spare, and the mark this bar leads to is already named
    // by the chip beside the part.
    return HudProgress(
      fraction: walked,
      reading: '$into / $span',
      place: HudReading.inside,
    );
  }
}

class _BuffRow extends StatelessWidget {
  const _BuffRow({required this.buff, required this.sim, this.scale = 1});

  final ArmBuff buff;
  final PrototypeSimulation sim;

  /// How hard the type is squeezed when the card is short of room.
  final double scale;

  /// What one row asks for when nothing is squeezing it.
  static const double naturalHeight = 15;

  @override
  Widget build(BuildContext context) {
    return HudRow(
      margin: EdgeInsets.only(bottom: scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // The name and its step travel together in one loose slot. They
          // used to be a Flexible and a Spacer side by side in the outer row,
          // which split the free width between them -- so the total stopped
          // short of the card's edge and the card read as too narrow.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    buff.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(9.5 * scale, color: Palette.textDim),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  buff.step,
                  style: AppText.display(9.5 * scale, color: Palette.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            buff.total(sim),
            style: AppText.display(
              11 * scale,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}
