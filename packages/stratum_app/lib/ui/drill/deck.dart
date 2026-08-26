/// The readouts laid over the rock, and the handle that folds them away.
library;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
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
              // The race the whole game is built on: rock hardness against bit
              // power, ending in the only number that answers "how long".
              Row(
                children: [
                  Stat(
                    label: 'щільність',
                    value: '${sim.layerHpMax.value}',
                    colour: Palette.textDim,
                  ),
                  const SizedBox(width: 18),
                  Stat(
                    label: 'сила',
                    value: '${sim.power.value}',
                    colour: Palette.gold,
                  ),
                  const Spacer(),
                  Stat(
                    label: 'до пробиття',
                    value: '${sim.cyclesToBreak.value} циклів',
                    colour: Palette.textDim,
                    alignEnd: true,
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
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Stat(
                                label: 'руда / цикл',
                                value: '${sim.orePerCycle.value}',
                                colour: Palette.ore,
                              ),
                              const SizedBox(width: 16),
                              Stat(
                                label: 'кристали',
                                value: '${(sim.crystalChance * 100).round()}%',
                                colour: Palette.crystal,
                                note:
                                    '+${PrototypeSimulation.crystalDropAt(sim.layer.value)}',
                              ),
                              const Spacer(),
                              Stat(
                                label: 'крит',
                                value: '${(sim.criticalChance * 100).round()}%',
                                colour: Palette.amber,
                                note: '×${sim.criticalMultiplier.round()}',
                                alignEnd: true,
                              ),
                            ],
                          ),
                        ],
                      )
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
