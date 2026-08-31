import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_diagram.dart';
import 'evolve_overlay.dart';
import 'batch_picker.dart';
import 'dissolve.dart';
import 'blow_summary.dart';
import 'part_card.dart';
import 'hud.dart';
import 'part_sheet.dart';
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
              const Dissolve(height: _dissolve),
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
          child: BlowSummary(game: game),
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
              BatchPicker(
                batch: _batch,
                onPick: (value) => setState(() => _batch = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const HudRule(),
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
                if (part != ArmPart.values.last) const HudRule(),
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
