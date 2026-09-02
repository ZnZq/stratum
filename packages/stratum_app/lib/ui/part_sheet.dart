import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'hud.dart';
import 'arm_style.dart';
import 'mark_glyph.dart';
import 'tokens.dart';
import 'buff_line.dart';

/// One part of the arm, generation by generation.
///
/// Opened from the part's own face on its card. Its whole job is to answer
/// "what does the next Mk get me?" -- and to answer it only as far as the
/// player has earned the right to know.
///
/// A generation the part has NEVER been built to keeps its buffs hidden and
/// its piece a silhouette: the reward for evolving is finding out. What the
/// player has once run stays readable forever, even after a restart takes the
/// levels back -- the hardware resets, what was learned about it does not.
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
    // The mark the part is BUILT to, not the one its level has walked into:
    // a part sitting at its ceiling has not reached the next mark until the
    // player rebuilds it, and the ladder must not say otherwise.
    final now = sim.markOf(part).value;
    final known = sim.knownGeneration(part);
    const count = PrototypeSimulation.markCount;

    return HudModal(
      title: style.label.toUpperCase(),
      // The piece itself rather than a symbol standing in for it, at the mark
      // it is built to -- the same drawing the ladder below repeats five
      // times.
      leading: MarkGlyph(part: part, mark: now, size: 26),
      accent: Palette.gold,
      inset: 18,
      // Set at the title's own size. Larger, it read as the main thing and
      // the name looked like it was floating above it -- the two share a
      // baseline either way, but the eye judges a line by its cap heights.
      trailing: Text(
        '$level / ${PrototypeSimulation.maxPartLevel}',
        style: AppText.display(
          11.5,
          weight: FontWeight.w700,
          color: Palette.gold,
        ),
      ),
      // The ladder keeps its own sides, so the rules between marks reach the
      // panel's edges the way they do between the parts on the screen behind.
      // Only 5 at the foot: the last mark row already carries 9 of its own,
      // and the two stacked read as the panel forgetting to end.
      // No air at the top: the sheet already rules a line under its title,
      // and a gap between that and the first mark reads as an empty strip.
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A list, not a tray of cards. Which mark the part stands at is
          // told by its lit piece and its gold type; a frame around it would
          // be one more island inside an island.
          for (var mk = 0; mk < count; mk++) ...[
            if (mk > 0) const HudRule(),
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
          ],
        ],
      ),
    );
  }
}

/// Where the player stands relative to one generation.
enum _MarkState {
  /// Run through and left behind.
  passed,

  /// The part is built to this mark now.
  current,

  /// Built in some earlier run, so its contents are remembered.
  known,

  /// Never built: its contents are the reward for getting there.
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
    // The level at which the mark is OBTAINED: 0/100/300/600/1000.
    final done = PrototypeSimulation.markCeiling(generation);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      // The piece leads the row. Every mark builds a different one, so the
      // ladder can be read down the left edge without reading a word of it.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkGlyph(part: part, mark: generation, lit: lit, hidden: !read),
          const SizedBox(width: 9),
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
                      'рівень $done',
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
                      Text(
                        'пройдено',
                        style: AppText.body(9, color: Palette.tech),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
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
                    BuffLine(
                      buff: buff,
                      stepColour: Palette.textFaint,
                      total: buff.total(sim),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
