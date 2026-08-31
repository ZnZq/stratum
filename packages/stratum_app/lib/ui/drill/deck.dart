/// The readouts laid over the rock, and the handle that folds them away.
library;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../stat.dart';
import '../tokens.dart';
import 'deck_handle.dart';
import 'loot_table.dart';

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
