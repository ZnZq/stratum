import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'drill_diagram.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'tabler_icons.dart';
import 'tokens.dart';
import 'upgrades_screen.dart';

/// One drill: the machine at work, what it is worth, and its three tracks.
///
/// Laid out like the manipulator, because it is the same kind of thing: a
/// piece of hardware you watch and pay into. The band runs edge to edge and
/// the panel below fades in over its foot, so the screen is one surface
/// rather than a tray of boxes.
class DrillDetail extends StatefulWidget {
  const DrillDetail({
    required this.game,
    required this.id,
    required this.onBack,
    super.key,
  });

  final Game game;
  final DrillId id;
  final VoidCallback onBack;

  @override
  State<DrillDetail> createState() => _DrillDetailState();
}

class _DrillDetailState extends State<DrillDetail> {
  /// How many levels one tap buys.
  int _batch = 1;

  static const double _band = 116;
  static const double _dissolve = 24;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final sim = game.sim;
    final row = PrototypeSimulation.rowFor(widget.id);

    return ColoredBox(
      color: Palette.scene,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DrillDiagram(game: game, id: widget.id, height: _band),
          ),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: _band - _dissolve),
                const _Dissolve(height: _dissolve),
                Expanded(child: _panel(game, sim, row)),
              ],
            ),
          ),
          // The way back, over the band where it costs no layout.
          Positioned(
            left: 6,
            top: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 11, 6),
                decoration: BoxDecoration(
                  color: const Color(0xB3141B26),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Palette.lineBar),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '‹',
                      style: AppText.display(14, color: Palette.textMuted),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'бури',
                      style: AppText.body(9.5, color: Palette.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Game game, PrototypeSimulation sim, DrillRow row) {
    final style = resourceStyles[row.mines]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Stat(
                  label: row.label,
                  labelColour: style.colour,
                  value: '${sim.drillArea(widget.id).round()} м²',
                  size: 13,
                  colour: style.colour,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stat(
                  label: 'цикл',
                  value: '${sim.drillInterval(widget.id).toStringAsFixed(2)} с',
                  size: 13,
                  colour: Palette.tech,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stat(
                  label: 'крит',
                  value:
                      '${(sim.drillCritChance(widget.id) * 100).toStringAsFixed(1)}%',
                  size: 13,
                  colour: Palette.gold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                'ПРОКАЧКА БУРА',
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
        // Intrinsic height, not an equal share of what is left: a track row
        // has nothing inside it that could use the slack, and three rows
        // stretched to fill the screen read as three empty boxes.
        for (final part in DrillPart.values) ...[
          _TrackRow(game: game, id: widget.id, part: part, batch: _batch),
          const _Rule(),
        ],
      ],
    );
  }
}

/// The join between the band and the panel: transparent at the top so the
/// face shows through it, the screen's own colour by the bottom.
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

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Palette.lineBar));
}

/// The x1 / x10 / max selector.
class _BatchPicker extends StatelessWidget {
  const _BatchPicker({required this.batch, required this.onPick});

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

/// One track of one drill: what it does, where it stands, what it costs.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.game,
    required this.id,
    required this.part,
    required this.batch,
  });

  final Game game;
  final DrillId id;
  final DrillPart part;
  final int batch;

  static const Map<DrillPart, (String, String)> _names = {
    DrillPart.radius: ('радіус', 'ширина вибою'),
    DrillPart.drive: ('привід', 'як часто циклить'),
    DrillPart.calibration: ('калібрування', 'крит і ехо'),
  };

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final level = sim.drill(id).levelOf(part).value;
    final capped = sim.drillAtCap(id, part);
    final steps = batch == 0 ? sim.affordableDrillLevels(id, part) : batch;
    final (name, note) = _names[part]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.shell,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Palette.lineBar),
                ),
                child: CustomPaint(
                  size: const Size(17, 17),
                  painter: _TrackGlyph(part),
                ),
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
                          name.toUpperCase(),
                          style: AppText.body(
                            8.5,
                            weight: FontWeight.w700,
                            color: Palette.tech,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          note,
                          style: AppText.body(9, color: Palette.textFaint),
                        ),
                        const Spacer(),
                        Text(
                          '$level',
                          style: AppText.display(
                            9.5,
                            weight: FontWeight.w600,
                            color: capped ? Palette.gold : Palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _Effect(sim: sim, id: id, part: part),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: capped
                    ? const _Flat(label: 'межа')
                    : _Buy(game: game, id: id, part: part, steps: steps),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the track is worth right now, and what one level adds.
class _Effect extends StatelessWidget {
  const _Effect({required this.sim, required this.id, required this.part});

  final PrototypeSimulation sim;
  final DrillId id;
  final DrillPart part;

  @override
  Widget build(BuildContext context) {
    final (now, step) = switch (part) {
      DrillPart.radius => (
        '${sim.drillRadius(id).round()} м · '
            '${sim.drillYieldScale(id).toString()}× здобичі',
        '+${PrototypeSimulation.drillRadiusPerLevel.round()} м',
      ),
      DrillPart.drive => (
        '${sim.drillInterval(id).toStringAsFixed(2)} с',
        '−${(PrototypeSimulation.drillSpeedStep * 100).round()}%',
      ),
      DrillPart.calibration => (
        'крит ${(sim.drillCritChance(id) * 100).toStringAsFixed(1)}% · '
            'ехо ${(sim.drillEchoChance(id) * 100).toStringAsFixed(2)}%',
        '+0.2 / +0.05 п.п.',
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            now,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(
              11,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(step, style: AppText.display(9.5, color: Palette.textFaint)),
      ],
    );
  }
}

class _Flat extends StatelessWidget {
  const _Flat({required this.label});

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

class _Buy extends StatelessWidget {
  const _Buy({
    required this.game,
    required this.id,
    required this.part,
    required this.steps,
  });

  final Game game;
  final DrillId id;
  final DrillPart part;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final affordable = sim.canUpgradeDrill(id, part) && steps > 0;
    return PressButton(
      onTap: affordable
          ? () => game.upgradeDrill(id, part, levels: steps)
          : null,
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
              '${sim.drillUpgradeCost(id, part)}',
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

/// The three tracks as three pieces of the machine, not three numbers.
class _TrackGlyph extends CustomPainter {
  const _TrackGlyph(this.part);

  final DrillPart part;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final steel = Paint()
      ..color = const Color(0xFF8794A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final bright = Paint()..color = Palette.gold;

    switch (part) {
      case DrillPart.radius:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(12, 13), width: 18, height: 10),
          steel,
        );
        canvas.drawLine(
          const Offset(12, 13),
          const Offset(21, 13),
          Paint()
            ..color = Palette.gold
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(const Offset(12, 13), 2, bright);
      case DrillPart.drive:
        canvas.drawCircle(const Offset(12, 12), 8, steel);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(16, 14.5),
          Paint()
            ..color = Palette.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round,
        );
      case DrillPart.calibration:
        canvas.drawPath(
          Path()
            ..moveTo(13, 3)
            ..lineTo(6, 13)
            ..lineTo(11, 13)
            ..lineTo(10, 21)
            ..lineTo(18, 10)
            ..lineTo(13, 10)
            ..close(),
          bright,
        );
    }
  }

  @override
  bool shouldRepaint(_TrackGlyph oldDelegate) => oldDelegate.part != part;
}
