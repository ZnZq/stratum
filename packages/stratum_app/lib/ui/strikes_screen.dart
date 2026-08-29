import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_diagram.dart';
import 'arm_style.dart';
import 'evolve_overlay.dart';
import 'hud.dart';
import 'part_glyph.dart';
import 'part_sheet.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

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
    // One surface, not a tray of boxes. The band runs edge to edge at the
    // top, the panel below fades in over its foot, and from there down the
    // only thing dividing anything is a hairline.
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ArmDiagram(game: game, height: _band),
        ),
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: _band - _dissolve),
              const _Dissolve(height: _dissolve),
              Expanded(child: _panel(game)),
            ],
          ),
        ),
      ],
    );
  }

  /// Everything under the rock: what a blow is worth, and the three parts.
  Widget _panel(Game game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _BlowSummary(game: game),
        ),
        const SizedBox(height: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
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
        ),
        const SizedBox(height: 8),
        const _Rule(),
        // All three parts belong on one screen: they are a choice between
        // each other, and a choice you have to scroll to see is not one.
        // They split the room that is left in equal parts; what gives when
        // the room is tight is the buff list inside a part, not the part.
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
                if (part != ArmPart.values.last) const _Rule(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// How tall the arm's band stands, and how much of its foot the panel
/// dissolves. The rock has to be thick enough here for the dissolve to have
/// something to eat: a hairline of stone under a gradient reads as a seam,
/// which is the one thing this layout is for.
const double _band = 104;
const double _dissolve = 24;

/// The join. Transparent at the top so the rock shows through it, the
/// screen's own colour by the bottom, and no line anywhere.
class _Dissolve extends StatelessWidget {
  const _Dissolve({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x001D2734), Color(0xE01D2734), Color(0xFF1D2734)],
            stops: [0, 0.62, 1],
          ),
        ),
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
    // Cut as ONE panel, not two plates: only the pair's outer corners are
    // struck, so the seam between them stays square.
    return Row(
      children: [
        Expanded(
          child: HudStat(
            label: 'сила удару',
            corners: const HudCorners(topLeft: true, bottomLeft: true),
            value: '${sim.strikePower}',
            size: 13,
            accent: Palette.gold,
            colour: Palette.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HudStat(
            label: 'реголіт за удар',
            align: CrossAxisAlignment.end,
            corners: const HudCorners(topRight: true, bottomRight: true),
            value: '${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}',
            size: 13,
            accent: Palette.ore,
            colour: Palette.ore,
            labelColour: Palette.ore,
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
    return HudChoice<int>(
      options: const [(1, '×1'), (10, '×10'), (0, 'макс')],
      value: batch,
      onPick: onPick,
      cut: 5,
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HudTap(
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
    return HudButton(
      onTap: null,
      label: label,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    const span = PrototypeSimulation.levelsPerGeneration;
    final into = level - mark * span;
    final walked = into / span;
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
    return HudButton(
      onTap: affordable ? () => game.upgradeArm(part, levels: steps) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
