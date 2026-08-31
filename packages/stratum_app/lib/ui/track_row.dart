import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'buy_button.dart';
import 'hud.dart';
import 'tokens.dart';

/// One track of one drill: what it does, where it stands, what it costs.
class TrackRow extends StatelessWidget {
  const TrackRow({
    required this.game,
    required this.id,
    required this.part,
    required this.batch,
    super.key,
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
                    ? const HudButton(
                        onTap: null,
                        label: 'межа',
                        padding: EdgeInsets.symmetric(vertical: 8),
                      )
                    : BuyButton(
                        cost: '${game.sim.drillUpgradeCost(id, part)}',
                        enabled:
                            game.sim.canUpgradeDrill(id, part) && steps > 0,
                        onTap: () => game.upgradeDrill(id, part, levels: steps),
                      ),
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
