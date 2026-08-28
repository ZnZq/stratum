import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'drill/metrics.dart';
import 'drill/rig.dart';
import 'drill/rock.dart';
import 'drill/shaft.dart';
import 'resource_style.dart';
import 'tokens.dart';

/// One drill at work, with the face it covers drawn under it.
///
/// The same steel as everywhere else -- the rig's own pipe and bit painters
/// over the metre the player is actually standing on -- because a drill that
/// looked like a different machine from the one in the mine would be a
/// different machine as far as the player is concerned.
///
/// What this diagram adds over the arm's is the SWEEP: a drill's radius is
/// its most important number and the only one with nothing to show for
/// itself, so the face carries the ring it covers.
class DrillDiagram extends StatefulWidget {
  const DrillDiagram({
    required this.game,
    required this.id,
    this.height = 116,
    super.key,
  });

  final Game game;
  final DrillId id;
  final double height;

  /// The height the machine itself is authored at; the band may be taller and
  /// the face simply runs down to meet it.
  static const double designHeight = 108;

  @override
  State<DrillDiagram> createState() => _DrillDiagramState();
}

/// Where the string is in its cycle.
typedef DrillBeat = ({double plunge, double sweep});

class _DrillDiagramState extends State<DrillDiagram>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final ValueNotifier<DrillBeat> _beat = ValueNotifier((
    plunge: 0.0,
    sweep: 0.0,
  ));
  final ValueNotifier<double> _flutes = ValueNotifier(0);
  final ValueNotifier<double> _heat = ValueNotifier(0);

  Duration _lastFrame = Duration.zero;
  double _clock = 0;
  double _spin = 0;

  /// The cycle, in seconds: drive, work the face, withdraw, rest. Longer on
  /// the working stretch than the arm's, because a drill is a machine that
  /// grinds rather than a hand that hits.
  static const double _driveEnd = 0.5;
  static const double _workEnd = 2.6;
  static const double _withdrawEnd = 3.0;
  static const double _period = 3.6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _clock = (_clock + delta) % _period;

    final working = _clock < _workEnd;
    final contact = _clock >= _driveEnd && _clock < _workEnd;

    _spin += ((working ? 1.0 : 0.0) - _spin) * math.min(1, delta * 5);
    _flutes.value = (_flutes.value + delta / rigFlutePeriod * _spin) % 1.0;
    _heat.value = contact
        ? math.min(1, _heat.value + delta / 0.9)
        : math.max(0, _heat.value - delta / 1.5);

    _beat.value = (plunge: _plungeAt(_clock), sweep: (_clock / _period));
  }

  double _plungeAt(double t) {
    if (t < _driveEnd) return _ease(t / _driveEnd) * 14;
    if (t < _workEnd) {
      // It does not hold still while it cuts: the string creeps down as the
      // face gives, which is what a bore looks like from the side.
      final into = (t - _driveEnd) / (_workEnd - _driveEnd);
      return 14 + into * 4 + math.sin(t * 34) * 0.7;
    }
    if (t < _withdrawEnd) {
      return 18 * (1 - _ease((t - _workEnd) / (_withdrawEnd - _workEnd)));
    }
    return 0;
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  @override
  void dispose() {
    _ticker.dispose();
    _beat.dispose();
    _flutes.dispose();
    _heat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.game.sim;
    return ClipRect(
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ShaftBackdrop(),
            RepaintBoundary(
              child: CustomPaint(
                painter: _DrillPainter(
                  beat: _beat,
                  flutes: _flutes,
                  heat: _heat,
                  layer: sim.layer.value,
                  tint:
                      resourceStyles[PrototypeSimulation.rowFor(widget.id)
                              .mines]!
                          .colour,
                  radius: sim.drillRadius(widget.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrillPainter extends CustomPainter {
  _DrillPainter({
    required this.beat,
    required this.flutes,
    required this.heat,
    required this.layer,
    required this.tint,
    required this.radius,
  }) : _bit = BitPainter(flutes: flutes, bite: heat),
       _pipe = PipePainter(flutes: flutes),
       _stones = StonePainter(layer: layer, thick: false),
       _cracks = CrackPainter(0.3, layer: layer),
       super(repaint: Listenable.merge([beat, flutes, heat]));

  final ValueListenable<DrillBeat> beat;
  final ValueListenable<double> flutes;
  final ValueListenable<double> heat;
  final int layer;

  /// The colour of what this drill brings up. The machine is the same steel
  /// whatever it mines; only its sweep is tinted, so the screen says which
  /// drill you are looking at without a word.
  final Color tint;

  /// The bore, in metres. Drawn as the ring it covers on the face.
  final double radius;

  final BitPainter _bit;
  final PipePainter _pipe;
  final StonePainter _stones;
  final CrackPainter _cracks;

  static const double _designWidth = 384;
  static const double _designHeight = DrillDiagram.designHeight;
  static const double _faceTop = 66;
  static const double _headRest = -8;
  static const double _pipeLength = 56;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.width / _designWidth;
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    final bottom = math.max(size.height / scale, _designHeight);

    _paintFace(canvas, bottom);
    _paintSweep(canvas, bottom);
    _paintString(canvas, beat.value);

    canvas.restore();
  }

  void _paintFace(Canvas canvas, double bottom) {
    final band = Rect.fromLTWH(
      0,
      _faceTop,
      _designWidth,
      bottom - _faceTop + 6,
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Strata.fillFor(layer),
        ).createShader(band),
    );

    canvas.save();
    canvas.translate(0, _faceTop);
    canvas.clipRect(Rect.fromLTWH(0, 0, _designWidth, band.height));
    _stones.paint(canvas, Size(_designWidth, band.height));
    _cracks.paint(canvas, Size(_designWidth, band.height));
    canvas.restore();

    canvas.drawLine(
      const Offset(0, _faceTop),
      const Offset(_designWidth, _faceTop),
      Paint()
        ..color = const Color(0x33A8C4E0)
        ..strokeWidth = 1,
    );
  }

  /// The face the bore covers, in the colour of what it brings up.
  ///
  /// Drawn as an ellipse rather than a circle because the face is seen at a
  /// glancing angle: the mine is a section, not a plan.
  void _paintSweep(Canvas canvas, double bottom) {
    final centre = Offset(_designWidth / 2, (_faceTop + bottom) / 2 + 4);
    // Compressed hard: the radius track runs to hundreds of metres and a
    // linear ring would leave the band before the first hundred. The ring
    // says "wider than before", not "this many metres".
    final drawn = 34 + 68 * (1 - math.exp(-radius / 90));
    for (final ring in [
      (drawn, 0.75, 1.5),
      (drawn * 0.62, 0.4, 1.2),
      (drawn * 0.3, 0.22, 1.0),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: centre,
          width: ring.$1 * 2,
          height: ring.$1 * 0.62,
        ),
        Paint()
          ..color = tint.withValues(alpha: ring.$2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.$3,
      );
    }
  }

  void _paintString(Canvas canvas, DrillBeat beat) {
    final head = Offset(_designWidth / 2, _headRest + beat.plunge);

    // No derrick drawn: the string comes down from above the frame, the
    // way it does in the mine. A mast inside the band read as a pill
    // floating over the shaft rather than the machine carrying on
    // off-screen.

    canvas.save();
    canvas.translate(head.dx - pipeWidth / 2, head.dy);
    _pipe.paint(canvas, const Size(pipeWidth, _pipeLength));
    canvas.restore();

    canvas.save();
    canvas.translate(head.dx - bitWidth / 2, head.dy + _pipeLength);
    _bit.paint(canvas, const Size(bitWidth, bitHeight));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrillPainter oldDelegate) =>
      oldDelegate.layer != layer ||
      oldDelegate.tint != tint ||
      oldDelegate.radius != radius;
}
