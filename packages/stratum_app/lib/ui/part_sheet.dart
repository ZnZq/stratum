import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_style.dart';
import 'stat.dart';
import 'tokens.dart';

/// One part of the arm, generation by generation.
///
/// Opened from the part's own face on its card. Its whole job is to answer
/// "what does the next Mk get me?" -- and to answer it only as far as the
/// player has earned the right to know.
///
/// A generation the part has NEVER been taken to keeps its buffs hidden: the
/// reward for evolving is finding out. What the player has once run, though,
/// stays readable forever, even after a restart takes the levels back -- the
/// hardware resets, what was learned about it does not.
class PartSheet extends StatelessWidget {
  const PartSheet({
    required this.game,
    required this.part,
    required this.onClose,
    super.key,
  });

  final Game game;
  final ArmPart part;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final style = armPartStyles[part]!;
    final level = sim.levelOf(part).value;
    final now = PrototypeSimulation.generationOf(level);
    final known = sim.knownGeneration(part);
    const count =
        PrototypeSimulation.maxPartLevel ~/
        PrototypeSimulation.levelsPerGeneration;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0xB3070A10)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: Palette.bar,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Palette.line),
                boxShadow: const [
                  BoxShadow(color: Color(0x8C000000), blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stat(
                    label: style.label,
                    value: '$level / ${PrototypeSimulation.maxPartLevel}',
                    note: style.note,
                    trailing: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Text(
                          '✕',
                          style: AppText.display(
                            12,
                            weight: FontWeight.w700,
                            color: Palette.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var mk = 0; mk < count; mk++) ...[
                    _Generation(
                      part: part,
                      generation: mk,
                      state: switch (mk) {
                        _ when mk < now => _MarkState.passed,
                        _ when mk == now => _MarkState.current,
                        _ when mk <= known => _MarkState.known,
                        _ => _MarkState.unknown,
                      },
                      sim: sim,
                    ),
                    if (mk < count - 1) const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the player stands relative to one generation.
enum _MarkState {
  /// Run through and left behind.
  passed,

  /// The part is here now.
  current,

  /// Reached in some earlier run, so its contents are remembered.
  known,

  /// Never reached: its contents are the reward for getting there.
  unknown,
}

class _Generation extends StatelessWidget {
  const _Generation({
    required this.part,
    required this.generation,
    required this.state,
    required this.sim,
  });

  final ArmPart part;
  final int generation;
  final _MarkState state;
  final PrototypeSimulation sim;

  @override
  Widget build(BuildContext context) {
    final opened = buffsOpenedBy(part, generation);
    final lit = state == _MarkState.current;
    final read = state != _MarkState.unknown;
    final from = generation * PrototypeSimulation.levelsPerGeneration + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: lit ? Palette.goldWell : Palette.well,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lit ? Palette.amber : Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                markName(generation),
                style: AppText.display(
                  11,
                  weight: FontWeight.w700,
                  color: switch (state) {
                    _MarkState.current => Palette.gold,
                    _MarkState.unknown => Palette.textFaint,
                    _ => Palette.textDim,
                  },
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'з $from рівня',
                style: AppText.body(9, color: Palette.textFaint),
              ),
              const Spacer(),
              if (state == _MarkState.current)
                Text(
                  'тут',
                  style: AppText.body(
                    9,
                    weight: FontWeight.w700,
                    color: Palette.gold,
                  ),
                )
              else if (state == _MarkState.passed)
                Text('пройдено', style: AppText.body(9, color: Palette.tech)),
            ],
          ),
          const SizedBox(height: 5),
          if (!read)
            Text(
              'дійди сюди, щоб дізнатись',
              style: AppText.body(9.5, color: Palette.textFaint),
            )
          else if (opened.isEmpty)
            Text(
              generation == 0
                  ? 'базові бафи деталі'
                  : 'нових бафів це покоління не додає',
              style: AppText.body(9.5, color: Palette.textFaint),
            )
          else
            for (final buff in opened)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      buff.label,
                      style: AppText.body(10, color: Palette.textDim),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      buff.step,
                      style: AppText.display(9.5, color: Palette.textFaint),
                    ),
                    const Spacer(),
                    if (state != _MarkState.unknown)
                      Text(
                        buff.total(sim),
                        style: AppText.display(
                          10.5,
                          weight: FontWeight.w700,
                          color: Palette.gold,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
