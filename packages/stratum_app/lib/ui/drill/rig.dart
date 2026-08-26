/// The rig hanging in the borehole: pipe, bit, charge gauge and the grip that
/// forces them.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../tick_ring.dart';
import '../tokens.dart';
import 'metrics.dart';
import 'overlays.dart';

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
    final charge = sim.energy.value / sim.energyCap;

    return IgnorePointer(
      child: Stack(
        children: [
          // Every readout in one band above the rig. The rig is a row across
          // the whole face now, so there is no longer a side of it to stand
          // beside, and the numbers would be drilled through.
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DepthReadout(game: game),
                const Spacer(),
                EnergyPlate(game: game),
                const SizedBox(width: 16),
                HeadStat(
                  // "Tick" is the engine's word. What the player sees is one
                  // pass of the drill, and the deck already counts those.
                  label: 'цикл',
                  value: game.tickInterval,
                  colour: Palette.textDim,
                ),
              ],
            ),
          ),
          // One column per drill, spread across the face. Each runs a hair out
          // of phase with its neighbour, so a row of them reads as machinery
          // rather than as one drill stamped seven times.
          Positioned(
            top: headTop,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < drawnDrills(sim.drills.value); i++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DrillPipe(charge: charge, phase: i * 0.13),
                      DrillBit(engine: game.drill, phase: i * 0.13),
                    ],
                  ),
              ],
            ),
          ),
          // Sized to the string it wraps: the tick belongs to the rig as a
          // whole, so there is one ring over the middle of it and not one per
          // drill.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: headTop),
              child: TickRing(engine: game.drill, diameter: stringLength),
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

/// The charge, as a plate with its own bar under it.
///
/// The number says where the gauge stands and the bar says the same thing in
/// one glance; the pale sliver at the bar's edge is the point currently being
/// earned, so the rhythm the label states in words is also visible.
class EnergyPlate extends StatelessWidget {
  const EnergyPlate({required this.game, super.key});

  final Game game;

  static const double _width = 142;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final spent = sim.energy.value < PrototypeSimulation.strikeCost;

    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              color: Palette.well,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Palette.lineBar),
            ),
            child: Row(
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
                const Spacer(),
                Text(
                  '${sim.energy.value}',
                  style: AppText.display(
                    16,
                    weight: FontWeight.w700,
                    color: spent ? Palette.textFaint : Palette.textDim,
                  ),
                ),
                Text(
                  ' / ${sim.energyCap}',
                  style: AppText.display(10.5, color: Palette.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          EnergyMeter(engine: game.energyLoop, full: sim.energyFull),
          const SizedBox(height: 4),
          Text(
            spent
                ? 'енергія відновлюється · '
                      '+${sim.energyPerRegen}/${Game.energyInterval}'
                : 'тап по породі — удар · '
                      '+${sim.energyPerRegen}/${Game.energyInterval}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.body(
              8.5,
              weight: FontWeight.w600,
              letterSpacing: 0.6,
              color: spent ? Palette.textFaint : Palette.tech,
              shadows: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar under the plate.
///
/// It asks the charge engine how far the current interval has been served,
/// once per frame, rather than running its own animation of the same length --
/// so it cannot drift away from the moment the point actually lands.
class EnergyMeter extends StatefulWidget {
  const EnergyMeter({required this.engine, required this.full, super.key});

  final TickEngine engine;
  final bool full;

  @override
  State<EnergyMeter> createState() => EnergyMeterState();
}

class EnergyMeterState extends State<EnergyMeter>
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
      child: SizedBox(
        height: 3,
        child: CustomPaint(
          painter: EnergyMeterPainter(_progress, full: widget.full),
        ),
      ),
    );
  }
}

class EnergyMeterPainter extends CustomPainter {
  EnergyMeterPainter(this.progress, {required this.full})
    : super(repaint: progress);

  /// How far the current interval has been served, in `[0, 1]`.
  ///
  /// The bar sweeps toward the NEXT point and snaps back as it lands: it is
  /// the metronome of the gauge, not its level. The level is the number on
  /// the plate; drawing it twice told the player nothing new.
  final ValueListenable<double> progress;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = const Color(0x66000000),
    );
    final swept = size.width * progress.value.clamp(0.0, 1.0);
    if (swept <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, swept, size.height), radius),
      Paint()
        ..shader = LinearGradient(
          // Gold once the gauge is full: the sweep has nowhere to land, so
          // the bar stands still and says "at the cap" instead.
          colors: full
              ? const [Palette.gold, Palette.gold]
              : const [Palette.tech, Palette.compute],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(EnergyMeterPainter oldDelegate) =>
      oldDelegate.full != full;
}

/// The pipe the bit hangs on.
///
/// Steel with the charge running through it as a lit core, rather than a bar
/// that is itself the gauge: the rig then reads as machinery whatever the
/// charge happens to be, and an empty gauge does not make the drill vanish.
class DrillPipe extends StatefulWidget {
  const DrillPipe({required this.charge, this.phase = 0, super.key});

  final double charge;

  /// Where this drill's flutes start, so neighbours do not turn in lockstep.
  final double phase;

  @override
  State<DrillPipe> createState() => DrillPipeState();
}

class DrillPipeState extends State<DrillPipe>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<double> _flutes = ValueNotifier(widget.phase);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;
    _flutes.value =
        (_flutes.value + delta.inMicroseconds / 1e6 / rigFlutePeriod) % 1.0;
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
        size: const Size(pipeWidth, stringLength),
        painter: PipePainter(flutes: _flutes, charge: widget.charge),
      ),
    );
  }
}

const double rigFlutePeriod = 0.4;

class PipePainter extends CustomPainter {
  PipePainter({required this.flutes, required this.charge})
    : super(repaint: flutes);

  final ValueListenable<double> flutes;
  final double charge;

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
      // A quarter of the barrel, not half: the core is what runs THROUGH the
      // pipe, and seven points on a fourteen-wide pipe made the steel read as
      // charge with a bit of trim on it.
      final bore = size.width * 0.26;
      final core = Rect.fromLTWH(
        (size.width - bore) / 2,
        size.height - lit,
        bore,
        lit,
      );
      canvas.drawRect(
        core,
        Paint()
          ..color = Palette.gold
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
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
  bool shouldRepaint(PipePainter oldDelegate) => oldDelegate.charge != charge;
}

/// The bit, cutting.
///
/// Two separate motions: the flutes scroll down the cone at their own speed,
/// which doubles under forcing, and the tip heats towards the moment the tick
/// lands. The heat is read from the engine rather than animated on a timer of
/// its own, so the flare peaks exactly when the layer takes the damage.
class DrillBit extends StatefulWidget {
  const DrillBit({required this.engine, this.phase = 0, super.key});

  final TickEngine engine;

  /// Where this bit's flutes start, matched to its own pipe.
  final double phase;

  @override
  State<DrillBit> createState() => DrillBitState();
}

class DrillBitState extends State<DrillBit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<double> _flutes = ValueNotifier(widget.phase);
  final ValueNotifier<double> _bite = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;
    _flutes.value =
        (_flutes.value + delta.inMicroseconds / 1e6 / rigFlutePeriod) % 1.0;
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
        size: const Size(bitWidth, bitHeight),
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

/// The rock face takes the blows.
///
/// A tap anywhere on the borehole is one strike; holding repeats them, and
/// the repeats wind up -- a held finger digs faster the longer it stays down,
/// so committing to a dig feels like leaning into it. It draws nothing: the
/// result shows in the rock and on the energy plate.
class StrikeZone extends StatefulWidget {
  const StrikeZone({required this.game, super.key});

  final Game game;

  @override
  State<StrikeZone> createState() => StrikeZoneState();
}

class StrikeZoneState extends State<StrikeZone> {
  Timer? _repeat;

  /// The wind-up: the first repeat lands after [_startMs], every following
  /// one comes [_stepMs] sooner, down to [_floorMs]. Release resets it.
  static const int _startMs = 200;
  static const int _floorMs = 100;
  static const int _stepMs = 10;

  int _intervalMs = _startMs;

  void _down() {
    widget.game.strike();
    _intervalMs = _startMs;
    _schedule();
  }

  void _schedule() {
    _repeat?.cancel();
    _repeat = Timer(Duration(milliseconds: _intervalMs), () {
      widget.game.strike();
      if (_intervalMs > _floorMs) {
        _intervalMs -= _stepMs;
        if (_intervalMs < _floorMs) _intervalMs = _floorMs;
      }
      _schedule();
    });
  }

  void _up() {
    _repeat?.cancel();
    _repeat = null;
    _intervalMs = _startMs;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
