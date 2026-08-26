/// The rig hanging in the borehole: pipe, bit, charge gauge and the grip that
/// forces them.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../tick_ring.dart';
import '../tokens.dart';
import 'metrics.dart';

/// The drill string, the tick ring, the bit — and the forcing charge.
///
/// The charge lives in the string rather than in a gauge of its own: it is fuel
/// standing in the pipe above the bit, and forcing burns it away from the top
/// down. One panel fewer, and the meaning needs no label.
class DrillString extends StatelessWidget {
  const DrillString({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final forcing = game.isForcing;
    final charge = sim.charge.value / PrototypeSimulation.chargeCap;

    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: headTop),
              child: DrillPipe(charge: charge, forcing: forcing),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: headTop + 16),
              child: TickRing(engine: game.drill, spinning: forcing),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: headTop + stringLength),
              child: DrillBit(engine: game.drill, forcing: forcing),
            ),
          ),
          // Charge and tick length sit either side of the head, out of the
          // channel the rock descends through.
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, top: headTop + 54),
              child: HeadStat(
                label: 'заряд +1/${Game.chargeInterval}',
                value: '${sim.charge.value}',
                align: CrossAxisAlignment.start,
                colour: forcing ? Palette.gold : Palette.textDim,
                meter: ChargeMeter(
                  engine: game.chargeLoop,
                  full: sim.chargeFull,
                ),
                caption: Text(
                  sim.charge.value < PrototypeSimulation.forcingCost
                      ? 'форсаж · нема заряду'
                      : (forcing ? 'форсаж · ×2 темп' : 'форсаж · утримуй'),
                  style: AppText.body(
                    9,
                    weight: forcing ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 1.4,
                    color: sim.charge.value < PrototypeSimulation.forcingCost
                        ? Palette.textFaint
                        : (forcing ? Palette.gold : Palette.tech),
                    shadows: true,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.54, -1),
            child: Padding(
              padding: const EdgeInsets.only(top: headTop + 54),
              child: HeadStat(
                label: 'тік',
                value: game.tickInterval,
                colour: forcing ? Palette.gold : Palette.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeadStat extends StatelessWidget {
  const HeadStat({
    required this.label,
    required this.value,
    required this.colour,
    this.meter,
    this.caption,
    this.align = CrossAxisAlignment.center,
    super.key,
  });

  final String label;
  final String value;
  final Color colour;
  final Widget? meter;
  final Widget? caption;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meter != null) ...[meter!, const SizedBox(height: 3)],
        Text(
          label.toUpperCase(),
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
            shadows: true,
          ),
        ),
        Text(
          value,
          style: AppText.display(
            13,
            weight: FontWeight.w700,
            color: colour,
            shadows: true,
          ),
        ),
        if (caption != null) ...[const SizedBox(height: 2), caption!],
      ],
    );
  }
}

/// The bar that fills between charge ticks.
///
/// It asks the charge engine how far the current interval has been served,
/// once per frame, rather than running its own animation of the same length --
/// so it cannot drift away from the moment the point actually lands.
class ChargeMeter extends StatefulWidget {
  const ChargeMeter({required this.engine, required this.full, super.key});

  final TickEngine engine;
  final bool full;

  @override
  State<ChargeMeter> createState() => ChargeMeterState();
}

class ChargeMeterState extends State<ChargeMeter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration _) {
    _progress.value = widget.full ? 1 : widget.engine.progress;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(96, 4),
        painter: ChargeMeterPainter(_progress, full: widget.full),
      ),
    );
  }
}

class ChargeMeterPainter extends CustomPainter {
  ChargeMeterPainter(this.progress, {required this.full})
    : super(repaint: progress);

  final ValueListenable<double> progress;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = const Color(0x66000000),
    );
    final filled = size.width * progress.value.clamp(0.0, 1.0);
    if (filled <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, filled, size.height), radius),
      Paint()
        ..shader = LinearGradient(
          colors: full
              ? const [Palette.gold, Palette.gold]
              : const [Palette.tech, Palette.compute],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(ChargeMeterPainter oldDelegate) =>
      oldDelegate.full != full;
}

/// The pipe the bit hangs on.
///
/// Steel with the charge running through it as a lit core, rather than a bar
/// that is itself the gauge: the rig then reads as machinery whatever the
/// charge happens to be, and an empty gauge does not make the drill vanish.
class DrillPipe extends StatefulWidget {
  const DrillPipe({required this.charge, required this.forcing, super.key});

  final double charge;
  final bool forcing;

  @override
  State<DrillPipe> createState() => DrillPipeState();
}

class DrillPipeState extends State<DrillPipe>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _flutes = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = elapsed - _lastFrame;
    _lastFrame = elapsed;
    _flutes.value =
        (_flutes.value +
            delta.inMicroseconds / 1e6 / rigFlutePeriod(widget.forcing)) %
        1.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(30, stringLength),
        painter: PipePainter(
          flutes: _flutes,
          charge: widget.charge,
          forcing: widget.forcing,
        ),
      ),
    );
  }
}

double rigFlutePeriod(bool forcing) => forcing ? 0.16 : 0.4;

class PipePainter extends CustomPainter {
  PipePainter({
    required this.flutes,
    required this.charge,
    required this.forcing,
  }) : super(repaint: flutes);

  final ValueListenable<double> flutes;
  final double charge;
  final bool forcing;

  static const double _fluteSpacing = 13;
  static const double _collarSpacing = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final barrel = Offset.zero & size;

    // Cross-section shading: the highlight sits left of centre so the pipe
    // reads as round rather than as a flat strip.
    canvas.drawRect(
      barrel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF171A21),
            Color(0xFF6E7787),
            Color(0xFFC3CAD6),
            Color(0xFF7C8595),
            Color(0xFF14171D),
          ],
          stops: [0, 0.2, 0.36, 0.7, 1],
        ).createShader(barrel),
    );

    canvas.save();
    canvas.clipRect(barrel);

    final slide = flutes.value * _fluteSpacing;
    final groove = Paint()
      ..strokeWidth = 3.4
      ..color = const Color(0x33000000);
    final relief = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x2EFFFFFF);
    for (
      var y = -_fluteSpacing;
      y < size.height + _fluteSpacing;
      y += _fluteSpacing
    ) {
      final top = y + slide;
      canvas.drawLine(Offset(0, top), Offset(size.width, top + 9), groove);
      canvas.drawLine(
        Offset(0, top - 2.4),
        Offset(size.width, top + 6.6),
        relief,
      );
    }

    // The charge, running down the inside of the pipe.
    final lit = size.height * charge.clamp(0.0, 1.0);
    if (lit > 0.5) {
      final core = Rect.fromLTWH(
        size.width / 2 - 3.5,
        size.height - lit,
        7,
        lit,
      );
      canvas.drawRect(
        core,
        Paint()
          ..color = forcing ? const Color(0xFFFFF0C8) : Palette.gold
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, forcing ? 6.5 : 3.5),
      );
      canvas.drawRect(
        core,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99EF9F27), Palette.gold],
          ).createShader(core),
      );
    }
    canvas.restore();

    // Collars: the joints between pipe sections.
    final collarEdge = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x73000000);
    for (var y = 7.0; y < size.height; y += _collarSpacing) {
      final collar = Rect.fromLTWH(-2, y, size.width + 4, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(collar, const Radius.circular(2)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF20242D),
              Color(0xFFAEB6C4),
              Color(0xFF565F6E),
              Color(0xFF191D24),
            ],
            stops: [0, 0.34, 0.72, 1],
          ).createShader(collar),
      );
      canvas.drawLine(
        Offset(-2, y + 5.5),
        Offset(size.width + 2, y + 5.5),
        collarEdge,
      );
    }

    final rim = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF0C0E13);
    canvas.drawLine(const Offset(0.5, 0), Offset(0.5, size.height), rim);
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      rim,
    );
  }

  @override
  bool shouldRepaint(PipePainter oldDelegate) =>
      oldDelegate.charge != charge || oldDelegate.forcing != forcing;
}

/// The bit, cutting.
///
/// Two separate motions: the flutes scroll down the cone at their own speed,
/// which doubles under forcing, and the tip heats towards the moment the tick
/// lands. The heat is read from the engine rather than animated on a timer of
/// its own, so the flare peaks exactly when the layer takes the damage.
class DrillBit extends StatefulWidget {
  const DrillBit({required this.engine, required this.forcing, super.key});

  final TickEngine engine;
  final bool forcing;

  @override
  State<DrillBit> createState() => DrillBitState();
}

class DrillBitState extends State<DrillBit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _flutes = ValueNotifier(0);
  final ValueNotifier<double> _bite = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = elapsed - _lastFrame;
    _lastFrame = elapsed;
    _flutes.value =
        (_flutes.value +
            delta.inMicroseconds / 1e6 / rigFlutePeriod(widget.forcing)) %
        1.0;
    _bite.value = widget.engine.progress;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flutes.dispose();
    _bite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(34, 20),
        painter: BitPainter(flutes: _flutes, bite: _bite),
      ),
    );
  }
}

class BitPainter extends CustomPainter {
  BitPainter({required this.flutes, required this.bite})
    : super(repaint: Listenable.merge([flutes, bite]));

  final ValueListenable<double> flutes;
  final ValueListenable<double> bite;

  static const double _fluteSpacing = 6.5;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = flutes.value;
    final heat = Curves.easeInQuad.transform(bite.value.clamp(0.0, 1.0));
    final tip = Offset(size.width / 2, size.height);

    // The rock glowing where the cone is working, drawn past the bit's own
    // bounds so the heat spills onto the layer below it.
    canvas.drawCircle(
      tip,
      14 + heat * 8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 190, 90, 0.16 + heat * 0.5),
            const Color(0x00EF9F27),
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: 14 + heat * 8)),
    );

    final cone = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(tip.dx, tip.dy)
      ..close();

    // Same round-section shading as the pipe, so the two read as one machine.
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF6B4408),
            Palette.amber,
            Color(0xFFFFF0C8),
            Color(0xFFD08A18),
            Color(0xFF5C3A06),
          ],
          stops: [0, 0.22, 0.4, 0.72, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.save();
    canvas.clipPath(cone);

    final groove = Paint()
      ..strokeWidth = 2.2
      ..color = const Color(0x40000000);
    final relief = Paint()
      ..strokeWidth = 0.9
      ..color = const Color(0x40FFFFFF);
    final slide = phase * _fluteSpacing;
    for (
      var y = -_fluteSpacing;
      y < size.height + _fluteSpacing;
      y += _fluteSpacing
    ) {
      final top = y + slide;
      canvas.drawLine(Offset(0, top), Offset(size.width, top + 5), groove);
      canvas.drawLine(
        Offset(0, top - 1.8),
        Offset(size.width, top + 3.2),
        relief,
      );
    }

    canvas.drawCircle(
      tip,
      4.5 + heat * 3.5,
      Paint()
        ..color = Color.fromRGBO(255, 245, 220, 0.35 + heat * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
    canvas.restore();

    // Carbide teeth along the cutting edges.
    final tooth = Paint()..color = const Color(0xFFEFF3F8);
    final toothShade = Paint()..color = const Color(0x59000000);
    for (var i = 1; i <= 3; i++) {
      final t = i / 4;
      for (final side in const [-1.0, 1.0]) {
        final edge = Offset.lerp(Offset(side < 0 ? 0 : size.width, 0), tip, t)!;
        final out = Offset(side * 2.6, 0.6);
        final path = Path()
          ..moveTo(edge.dx, edge.dy - 1.8)
          ..lineTo(edge.dx + out.dx, edge.dy + out.dy)
          ..lineTo(edge.dx, edge.dy + 1.8)
          ..close();
        canvas.drawPath(path, tooth);
        canvas.drawPath(path.shift(const Offset(0, 0.9)), toothShade);
      }
    }

    // Swarf thrown off the edge, one fleck per flute passing the tip.
    final spark = Paint()
      ..color = Color.fromRGBO(255, 215, 130, 0.25 + heat * 0.55)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final travel = (phase + i / 3) % 1.0;
      final away = 3 + travel * 9;
      final side = i.isEven ? 1.0 : -1.0;
      final from = tip + Offset(side * away * 0.7, away * 0.35);
      canvas.drawLine(from, from + Offset(side * 2.4, 1.2), spark);
    }
  }

  @override
  bool shouldRepaint(BitPainter oldDelegate) => false;
}

/// The rock face is the forcing handle.
///
/// Holding anywhere on the borehole burns the charge, so the gesture is the
/// whole scene rather than a target the player has to aim at. It draws
/// nothing: what the press does is written under the charge gauge it spends.
class ForcingGrip extends StatelessWidget {
  const ForcingGrip({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => game.startForcing(),
        onPointerUp: (_) => game.stopForcing(),
        onPointerCancel: (_) => game.stopForcing(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
