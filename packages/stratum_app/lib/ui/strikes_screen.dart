import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_diagram.dart';
import 'arm_style.dart';
import 'evolve_overlay.dart';
import 'part_glyph.dart';
import 'part_sheet.dart';
import 'stat.dart';
import 'tabler_icons.dart';
import 'tokens.dart';
import 'upgrades_screen.dart';

/// The manipulator arm: what a blow is worth, and the three parts that grow it.
///
/// Its own screen beside «Бури» because the two lanes are two different
/// investments: the drills work while the player is away, the arm only pays
/// while a finger is on the rock.
class StrikesScreen extends StatefulWidget {
  const StrikesScreen({required this.game, super.key});

  final Game game;

  @override
  State<StrikesScreen> createState() => _StrikesScreenState();
}

class _StrikesScreenState extends State<StrikesScreen> {
  /// How many levels one tap buys. Five hundred levels a tap at a time is not
  /// a decision, it is a chore.
  int _batch = 1;

  /// The part whose generations are open for reading, if any.
  ArmPart? _reading;

  /// A rebuild the player just triggered, waiting to be watched.
  ({ArmPart part, int from, int to})? _evolved;

  void _evolve(ArmPart part) {
    final from = widget.game.sim.markOf(part).value;
    final to = widget.game.evolveArm(part);
    if (to == null) return;
    setState(() => _evolved = (part: part, from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return ColoredBox(
      color: Palette.scene,
      child: Stack(
        children: [
          _body(game),
          if (_reading case final part?)
            Positioned.fill(
              child: PartSheet(
                game: game,
                part: part,
                onClose: () => setState(() => _reading = null),
              ),
            ),
          if (_evolved case final done?)
            Positioned.fill(
              child: EvolveOverlay(
                part: done.part,
                from: done.from,
                to: done.to,
                onClose: () => setState(() => _evolved = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(Game game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArmDiagram(game: game),
          const SizedBox(height: 10),
          _BlowSummary(game: game),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'ПРОКАЧКА РУКИ',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.tech,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              _BatchPicker(
                batch: _batch,
                onPick: (value) => setState(() => _batch = value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // All three parts belong on one screen: they are a choice between
          // each other, and a choice you have to scroll to see is not one.
          // They split the room that is left in equal parts and keep the
          // panel's full width -- what gives when the room is tight is the
          // buff list inside each card, not the card.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final part in ArmPart.values) ...[
                  Expanded(
                    child: PartCard(
                      game: game,
                      part: part,
                      batch: _batch,
                      onRead: () => setState(() => _reading = part),
                      onEvolve: () => _evolve(part),
                    ),
                  ),
                  if (part != ArmPart.values.last) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a blow is worth right now: the power it lands with, and the band of
/// regolith it comes back with.
///
/// The two ends of that band are what the bit and the drive buy, so the
/// screen states them before it offers to sell anything.
class _BlowSummary extends StatelessWidget {
  const _BlowSummary({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    // No wells around them. They are the diagram's caption, not two more
    // panels stacked over the three below -- and dropping the frames is the
    // cheapest height the screen had left to give the cards.
    return Row(
      children: [
        Expanded(
          child: Stat(
            label: 'сила удару',
            value: '${sim.strikePower}',
            size: 13,
            colour: Palette.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stat(
            label: 'реголіт за удар',
            value: '${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}',
            size: 13,
            colour: Palette.ore,
          ),
        ),
      ],
    );
  }
}

/// The ×1 / ×10 / max selector.
class _BatchPicker extends StatelessWidget {
  const _BatchPicker({required this.batch, required this.onPick});

  /// A batch of zero means "as many as the store can pay for".
  final int batch;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Palette.lineBar),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in const [
            (1, '×1'),
            (10, '×10'),
            (0, 'макс'),
          ])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(value),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 4),
                color: value == batch ? Palette.goldWell : null,
                child: Text(
                  label,
                  style: AppText.body(
                    9,
                    weight: FontWeight.w700,
                    color: value == batch ? Palette.gold : Palette.textFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRead,
                child: PartFace(part: part, mark: mark, lit: ready, size: 32),
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
                        Text(
                          style.label.toUpperCase(),
                          style: AppText.body(
                            8.5,
                            weight: FontWeight.w700,
                            color: Palette.tech,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _MarkTag(generation: mark),
                        const Spacer(),
                        Text(
                          '$level',
                          style: AppText.display(
                            9.5,
                            weight: FontWeight.w600,
                            color: ready || maxed
                                ? Palette.gold
                                : Palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _GenerationTrack(generation: mark),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                // One width whatever the price says, so the card does not
                // twitch every time a purchase moves the cost up a digit.
                width: 104,
                child: maxed
                    ? const _FlatButton(label: 'межа')
                    : _BuyButton(game: game, part: part, steps: steps),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The road to the next mark, on its own line where it has room --
          // and once the road is walked, the line becomes the act itself.
          if (ready)
            _EvolveButton(onTap: onEvolve)
          else
            _MarkProgress(part: part, sim: sim, mark: mark, level: level),
          const SizedBox(height: 6),
          const _Rule(),
          const SizedBox(height: 5),
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

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Palette.lineBar));
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
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      decoration: BoxDecoration(
        color: opened ? Palette.goldWell : Palette.card,
        borderRadius: BorderRadius.circular(5),
      ),
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
    const count =
        PrototypeSimulation.maxPartLevel ~/
        PrototypeSimulation.levelsPerGeneration;
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

/// The card's one dead state: nothing left to buy or build.
class _FlatButton extends StatelessWidget {
  const _FlatButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.shell,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Text(
        label,
        style: AppText.body(
          10.5,
          weight: FontWeight.w700,
          color: Palette.textFaint,
        ),
      ),
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
    return PressButton(
      onTap: onTap,
      background: Palette.goldWell,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Center(
        child: Text(
          'ЕВОЛЮЦІЯ',
          style: AppText.body(
            10,
            weight: FontWeight.w700,
            color: Palette.gold,
            letterSpacing: 1.2,
          ),
        ),
      ),
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
    final floor = mark * PrototypeSimulation.levelsPerGeneration;
    final walked = (level - floor) / PrototypeSimulation.levelsPerGeneration;
    final ceiling = sim.ceilingOf(part);
    // The reading rides INSIDE the bar. It stood beside it as "63 до Mk III",
    // which spent a column of the card on a sentence about what the bar was
    // already showing.
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 13,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Palette.shell),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: walked.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Palette.amber, Palette.gold],
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                '$level / $ceiling',
                // Lit and shadowed: the ground under it is dark on one side
                // of the fill and bright on the other.
                style: AppText.display(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.text,
                  shadows: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.game,
    required this.part,
    required this.steps,
  });

  final Game game;
  final ArmPart part;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final affordable = sim.canUpgrade(part) && steps > 0;
    return PressButton(
      onTap: affordable ? () => game.upgradeArm(part, levels: steps) : null,
      background: affordable ? Palette.goldWell : Palette.card,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Ti.stack2,
            size: 12,
            color: affordable ? Palette.gold : Palette.textFaint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${sim.upgradeCost(part)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                11.5,
                weight: FontWeight.w700,
                color: affordable ? Palette.gold : Palette.textFaint,
              ),
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: EdgeInsets.only(bottom: scale),
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
