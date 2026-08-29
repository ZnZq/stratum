/// The readouts laid over the rock, and the handle that folds them away.
library;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../resource_plate.dart';
import '../stat.dart';
import '../hud.dart';
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
                        align: CrossAxisAlignment.end,
                      ),
                      const SizedBox(height: 7),
                      Stat(
                        label: 'до пробиття',
                        value: '${sim.hitsToBreak.value} ударів',
                        align: CrossAxisAlignment.end,
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
/// What a strike can bring up: a grid of plates, two to a row.
///
/// Regolith heads it on a row of its own -- the one certain lane, quoting a
/// band rather than a figure. Under it the chances: the ore ladder, crystals,
/// and the two exotic lanes paired at the foot. Ores still locked by depth
/// stay listed and dimmed, so the grid doubles as the map of what going
/// deeper opens.
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
            final half = (constraints.maxWidth - _gap) / 2;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                // Regolith takes the whole row: it is the one lane that is
                // certain, and it quotes a band rather than a figure, which
                // needs the width.
                ResourcePlate(
                  id: ResourceId.regolith,
                  amount: '${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}',
                  width: constraints.maxWidth,
                  shadows: true,
                ),
                for (final row in PrototypeSimulation.oreTable)
                  if (layer >= row.unlockAt)
                    ResourcePlate(
                      id: row.id,
                      aside: '${(row.chance * 100).round()}%',
                      amount: '${PrototypeSimulation.oreDropAt(layer)}',
                      width: half,
                      shadows: true,
                    )
                  else
                    ResourcePlate(
                      id: row.id,
                      amount: 'з ${row.unlockAt} м',
                      width: half,
                      dim: true,
                      shadows: true,
                    ),
                ResourcePlate(
                  id: ResourceId.crystals,
                  aside: '${(sim.crystalChance * 100).round()}%',
                  amount: '${PrototypeSimulation.crystalDropAt(layer)}',
                  width: half,
                  shadows: true,
                ),
                // The two exotic lanes close the table side by side: same
                // odds, both outside the ore ladder, and both worth nothing
                // to the rig -- one is the anti-brick drip, the other the
                // simulation's own substrate.
                ResourcePlate(
                  id: ResourceId.quantonium,
                  aside:
                      '${(PrototypeSimulation.strikeQuantoniumChance * 100).toStringAsFixed(0)}%',
                  amount: '${PrototypeSimulation.quantoniumDropAt(layer)}',
                  width: half,
                  shadows: true,
                ),
                ResourcePlate(
                  id: ResourceId.rawData,
                  aside:
                      '${(PrototypeSimulation.rawDataChance * 100).toStringAsFixed(0)}%',
                  amount: '${PrototypeSimulation.rawDataDropAt(layer)}',
                  width: half,
                  shadows: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class DeckHandle extends StatelessWidget {
  const DeckHandle({required this.expanded, required this.onTap, super.key});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudTap(
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
