import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'arm_diagram.dart';
import 'arm_style.dart';
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

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return ColoredBox(
      color: Palette.scene,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          const ArmDiagram(),
          const SizedBox(height: 9),
          _EnergyBar(game: game),
          const SizedBox(height: 9),
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
          const SizedBox(height: 8),
          for (final part in ArmPart.values) ...[
            PartCard(game: game, part: part, batch: _batch),
            if (part != ArmPart.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// The gauge, said as what it actually governs: the length of a burst, and
/// the pace the arm falls back to once the burst is spent.
class _EnergyBar extends StatelessWidget {
  const _EnergyBar({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final filled = sim.energy.value / sim.energyCap;
    final perSecond = game.energyPerSecond;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'ЕНЕРГІЯ',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.tech,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${sim.energy.value}',
                style: AppText.display(
                  13,
                  weight: FontWeight.w700,
                  color: Palette.textDim,
                ),
              ),
              Text(
                ' / ${sim.energyCap}',
                style: AppText.display(9.5, color: Palette.textFaint),
              ),
              const Spacer(),
              Text(
                'ривок ${sim.energyCap} · далі '
                '${perSecond.toStringAsFixed(2)} удару/с',
                style: AppText.display(
                  9.5,
                  weight: FontWeight.w600,
                  color: Palette.textFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Palette.shell),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: filled.clamp(0.0, 1.0),
                    child: const ColoredBox(color: Palette.gold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    super.key,
  });

  final Game game;
  final ArmPart part;
  final int batch;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final level = sim.levelOf(part).value;
    final generation = PrototypeSimulation.generationOf(level);
    final maxed = sim.atMaxLevel(part);
    final style = armPartStyles[part]!;
    final steps = batch == 0 ? sim.affordableLevels(part) : batch;

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PartFace(part: part, maxed: maxed),
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
                        _MarkTag(generation: generation),
                        const Spacer(),
                        Text(
                          '$level / ${PrototypeSimulation.maxPartLevel}',
                          style: AppText.display(
                            9.5,
                            weight: FontWeight.w600,
                            color: maxed ? Palette.gold : Palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _GenerationTrack(generation: generation),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (maxed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.shell,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Palette.lineBar),
                  ),
                  child: Text(
                    'межа',
                    style: AppText.body(
                      10.5,
                      weight: FontWeight.w700,
                      color: Palette.textFaint,
                    ),
                  ),
                )
              else
                _BuyButton(game: game, part: part, steps: steps),
            ],
          ),
          const SizedBox(height: 8),
          const _Rule(),
          const SizedBox(height: 7),
          for (final buff in buffsOf(part, generation))
            _BuffRow(buff: buff, sim: sim),
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

class _PartFace extends StatelessWidget {
  const _PartFace({required this.part, required this.maxed});

  final ArmPart part;
  final bool maxed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.shell,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: maxed ? Palette.amber : Palette.line),
              ),
              child: CustomPaint(
                size: const Size(24, 24),
                painter: _PartGlyph(part),
              ),
            ),
          ),
          // The same numeral the diagram above puts on this piece.
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.goldWell,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.amber),
              ),
              child: Text(
                '${part.index + 1}',
                style: AppText.display(
                  8,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A technical detail of the part, in the same steel as the diagram.
class _PartGlyph extends CustomPainter {
  const _PartGlyph(this.part);

  final ArmPart part;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final steel = Paint()..color = const Color(0xFF8794A6);
    final bright = Paint()..color = Palette.gold;

    switch (part) {
      case ArmPart.bit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 3, 8, 11),
            const Radius.circular(1),
          ),
          steel,
        );
        final flute = Paint()
          ..color = Palette.lineBar
          ..strokeWidth = 1.4;
        canvas.drawLine(const Offset(8, 6), const Offset(16, 6), flute);
        canvas.drawLine(const Offset(8, 9), const Offset(16, 9), flute);
        canvas.drawPath(
          Path()
            ..moveTo(8, 14)
            ..lineTo(16, 14)
            ..lineTo(12, 21)
            ..close(),
          bright,
        );
      case ArmPart.drive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 8, 12, 8),
            const Radius.circular(2),
          ),
          Paint()..color = Palette.edge,
        );
        final rib = Paint()
          ..color = Palette.lineBar
          ..strokeWidth = 1.1;
        for (final x in const [5.0, 8.0, 11.0]) {
          canvas.drawLine(Offset(x, 8), Offset(x, 16), rib);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 10.5, 7, 3),
            const Radius.circular(1.5),
          ),
          bright,
        );
      case ArmPart.supply:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 5, 18, 14),
          const Radius.circular(3),
        );
        canvas.drawRRect(body, Paint()..color = Palette.card);
        canvas.drawRRect(
          body,
          Paint()
            ..color = Palette.edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 8)
            ..lineTo(16, 8)
            ..lineTo(13, 11.5)
            ..lineTo(17, 11.5)
            ..lineTo(11, 17)
            ..lineTo(13, 12.5)
            ..lineTo(9, 12.5)
            ..close(),
          bright,
        );
        canvas.drawCircle(
          const Offset(6.5, 8.5),
          1.1,
          Paint()..color = Palette.edge,
        );
        canvas.drawCircle(
          const Offset(6.5, 15.5),
          1.1,
          Paint()..color = Palette.edge,
        );
    }
  }

  @override
  bool shouldRepaint(_PartGlyph oldDelegate) => oldDelegate.part != part;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Ti.stack2,
            size: 12,
            color: affordable ? Palette.gold : Palette.textFaint,
          ),
          const SizedBox(width: 6),
          Text(
            '${sim.upgradeCost(part)}',
            style: AppText.body(
              11.5,
              weight: FontWeight.w700,
              color: affordable ? Palette.gold : Palette.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuffRow extends StatelessWidget {
  const _BuffRow({required this.buff, required this.sim});

  final ArmBuff buff;
  final PrototypeSimulation sim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(buff.label, style: AppText.body(10, color: Palette.textDim)),
          const SizedBox(width: 6),
          Text(
            buff.step,
            style: AppText.display(9.5, color: Palette.textFaint),
          ),
          const Spacer(),
          Text(
            buff.total(sim),
            style: AppText.display(
              11,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}
