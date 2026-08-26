/// The readouts laid over the rock, and the handle that folds them away.
library;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../resource_style.dart';
import '../tokens.dart';

/// The rig's controls, laid on a deck that fades the rock out beneath them.
class Deck extends StatefulWidget {
  const Deck({required this.game, super.key});

  final Game game;

  @override
  State<Deck> createState() => DeckState();
}

class DeckState extends State<Deck> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sim = widget.game.sim;

    return Listener(
      // Swallows presses that land on the deck but miss a control: the rock
      // behind it is the forcing handle, and it covers the whole screen.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x001E2834), Color(0xE61E2834), Color(0xF71E2834)],
            stops: [0, 0.42, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeckHandle(
                expanded: _expanded,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              const SizedBox(height: 10),
              // The race the whole game is built on: what the blow is worth,
              // against the rock that answers "how long". The strike's whole
              // story runs along the left; the rock's answer stands in its
              // own column on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The strike trio scales down inside its slot if its
                  // numbers ever outgrow it; the rock's column keeps its
                  // size and its right edge.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      // Two rows, one theme: everything on the left is the
                      // blow, everything on the right column is the rock --
                      // the panel reads as "my strike against this layer".
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stat(
                            label: 'сила удару',
                            value: '${sim.strikePower}',
                            colour: Palette.gold,
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stat(
                                label: 'шанс крита',
                                value:
                                    '${(PrototypeSimulation.strikeCritChance * 100).round()}%',
                                colour: Palette.amber,
                              ),
                              const SizedBox(width: 14),
                              Stat(
                                label: 'сила крита',
                                value:
                                    '×${PrototypeSimulation.strikeCritPower.toStringAsFixed(2)}',
                                colour: Palette.amber,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stat(
                        label: 'щільність',
                        value: '${sim.layerHpMax.value}',
                        colour: Palette.textDim,
                        alignEnd: true,
                      ),
                      const SizedBox(height: 7),
                      Stat(
                        label: 'до пробиття',
                        value: '${sim.hitsToBreak.value} ударів',
                        colour: Palette.textDim,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              ),
              // What a cycle pays out, as opposed to what it costs the rock.
              // Folded away by default: it is worth checking now and then, not
              // worth the screen it takes while watching the bit work.
              AnimatedSize(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? LootTable(sim: sim)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grab bar that folds the upgrades away.
///
/// Collapsed, the deck keeps only what the player watches while drilling --
/// hardness, power, cycles left -- and hands the rest of the screen back to
/// the rock.
/// What a strike can bring up: a grid of plates, three to a row.
///
/// Regolith is the guaranteed haul, so its plate spans the full row and
/// quotes the band a blow can land in; everything under it is chance, name on
/// the left, odds on the right. Ores still locked by depth stay listed and
/// dimmed -- the grid doubles as the map of what going deeper opens.
class LootTable extends StatelessWidget {
  const LootTable({required this.sim, super.key});

  final PrototypeSimulation sim;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final layer = sim.layer.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'ЗДОБИЧ ЗА УДАР',
          style: AppText.body(
            8,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final third = (constraints.maxWidth - 2 * _gap) / 3;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                LootCard(
                  id: ResourceId.regolith,
                  amount: '${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}',
                  width: constraints.maxWidth,
                ),
                for (final row in PrototypeSimulation.oreTable)
                  if (layer >= row.unlockAt)
                    LootCard(
                      id: row.id,
                      chance: '${(row.chance * 100).round()}%',
                      amount: '${PrototypeSimulation.oreDropAt(layer)}',
                      width: third,
                    )
                  else
                    LootCard(
                      id: row.id,
                      chance: 'з ${row.unlockAt} м',
                      amount: '—',
                      width: third,
                      locked: true,
                    ),
                LootCard(
                  id: ResourceId.crystals,
                  chance: '${(sim.crystalChance * 100).round()}%',
                  amount: '${PrototypeSimulation.crystalDropAt(layer)}',
                  width: third,
                ),
                LootCard(
                  id: ResourceId.quantonium,
                  chance:
                      '${(PrototypeSimulation.strikeQuantoniumChance * 100).toStringAsFixed(0)}%',
                  amount: '${PrototypeSimulation.quantoniumDropAt(layer)}',
                  width: third,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The sketched plate: name left, odds right, and the framed cell under them
/// with the icon breaking out of its left edge.
class LootCard extends StatelessWidget {
  const LootCard({
    required this.id,
    required this.amount,
    required this.width,
    this.chance,
    this.locked = false,
    super.key,
  });

  final ResourceId id;

  /// The odds line, or null for a guaranteed drop: certainty needs no label.
  final String? chance;

  final String amount;
  final double width;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      style.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        8.5,
                        weight: FontWeight.w600,
                        color: Palette.textMuted,
                        shadows: true,
                      ),
                    ),
                  ),
                  if (chance != null)
                    Text(
                      chance!,
                      style: AppText.display(
                        8.5,
                        weight: FontWeight.w600,
                        color: Palette.textFaint,
                        shadows: true,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
              decoration: BoxDecoration(
                color: Palette.well,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: locked
                      ? Palette.lineBar
                      : style.colour.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(style.icon, size: 14, color: style.colour),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.display(
                        10.5,
                        weight: FontWeight.w700,
                        color: locked ? Palette.textFaint : Palette.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeckHandle extends StatelessWidget {
  const DeckHandle({required this.expanded, required this.onTap, super.key});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 1, color: const Color(0x337FD9C4)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Palette.shell,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x4D7FD9C4)),
              ),
              child: AnimatedRotation(
                turns: expanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                child: const CustomPaint(
                  size: Size(13, 7),
                  painter: ChevronPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChevronPainter extends CustomPainter {
  const ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.tech
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(ChevronPainter oldDelegate) => false;
}

class Stat extends StatelessWidget {
  const Stat({
    required this.label,
    required this.value,
    required this.colour,
    this.note,
    this.alignEnd = false,
    super.key,
  });

  final String label;
  final String value;
  final Color colour;
  final String? note;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: AppText.display(14, weight: FontWeight.w600, color: colour),
        ),
        if (note != null)
          Text(note!, style: AppText.display(9.5, color: Palette.textFaint)),
      ],
    );
  }
}
