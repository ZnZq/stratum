import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game.dart';
import 'drill/metrics.dart';
import 'drill/rig.dart';
import 'drill/rock.dart';
import 'drill/shaft.dart';
import 'tokens.dart';

/// The manipulator arm at work, with its three upgradeable parts called out.
///
/// The head and the face are the rig's own painters, not lookalikes: the arm
/// carries the same bit the drill strings carry, so it has to be the same
/// steel, the same heat and the same swarf -- and the rock it works is the
/// metre the player is actually standing on, textured and salted with the
/// same ore the mine draws.
///
/// It runs a loop of its own -- one stroke, then a rest -- because a still
/// diagram of a hammering arm reads as a picture of a broken one.
class ArmDiagram extends StatefulWidget {
  const ArmDiagram({required this.game, this.height = 104, super.key});

  final Game game;

  /// The band the arm is drawn on. It runs the full width of the screen,
  /// so the rock below the bit is the screen's own ground rather than the
  /// floor of a box sitting on it.
  final double height;

  /// The height the ARM ITSELF is authored at. The band may be taller; the
  /// face simply runs on down to meet it.
  static const double designHeight = 86;

  @override
  State<ArmDiagram> createState() => _ArmDiagramState();
}

/// Where the arm is in its stroke.
typedef ArmBeat = ({
  /// How far the wrist has driven toward the face, in design pixels.
  /// Negative is the wind-up.
  double plunge,
});

class _ArmDiagramState extends State<ArmDiagram>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final ValueNotifier<ArmBeat> _beat = ValueNotifier((plunge: 0.0));

  /// Handed straight to the rig's own bit painter, which reads them as the
  /// flutes' phase and as how hard the head is working.
  final ValueNotifier<double> _flutes = ValueNotifier(0);
  final ValueNotifier<double> _heat = ValueNotifier(0);

  Duration _lastFrame = Duration.zero;

  /// Seconds into the stroke, wrapping at [_period].
  double _clock = 0;
  double _spin = 0;

  /// The stroke, in seconds: lift, drive, work the face, withdraw, rest.
  /// The working stretch is the long one -- it is the part worth watching.
  static const double _liftEnd = 0.32;
  static const double _driveEnd = 0.52;
  static const double _workEnd = 1.95;
  static const double _withdrawEnd = 2.28;
  static const double _period = 3.2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _clock = (_clock + delta) % _period;

    final working = _clock >= _liftEnd && _clock < _workEnd;
    final contact = _clock >= _driveEnd && _clock < _workEnd;

    // The head keeps its momentum: it spins up before the blow and coasts
    // down after it, rather than snapping between turning and still.
    _spin += ((working ? 1.0 : 0.0) - _spin) * math.min(1, delta * 5);
    _flutes.value = (_flutes.value + delta / rigFlutePeriod * _spin) % 1.0;

    // Cosmetic only. The bit painter reads this as how hard the head is
    // working; nothing in the simulation ever asks.
    _heat.value = contact
        ? math.min(1, _heat.value + delta / 0.8)
        : math.max(0, _heat.value - delta / 1.6);

    _beat.value = (plunge: _plungeAt(_clock));
  }

  /// Zero is the arm at rest, holding the bit clear of the face; the stroke
  /// lifts a little further first and then drives past the rock line.
  double _plungeAt(double t) {
    if (t < _liftEnd) return _ease(t / _liftEnd) * -6;
    if (t < _driveEnd) {
      return -6 + _ease((t - _liftEnd) / (_driveEnd - _liftEnd)) * 20;
    }
    if (t < _workEnd) {
      // A blow is not one push: the head hammers where it stands.
      return 14 + math.sin((t - _driveEnd) * 46) * 1.1;
    }
    if (t < _withdrawEnd) {
      return 14 - _ease((t - _workEnd) / (_withdrawEnd - _workEnd)) * 14;
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
    // No frame. The band is the top of the screen the way the borehole is
    // the whole of the mine: the panel below fades in over its foot, so the
    // two meet in a dissolve instead of on a border.
    return ClipRect(
      child: SizedBox(
        height: widget.height,
        // The void above the rock is the borehole, so it gets the borehole's
        // own drifting field rather than a flat fill -- the same backdrop the
        // mine stands on, on its own ticker behind the arm.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ShaftBackdrop(),
            RepaintBoundary(
              child: CustomPaint(
                painter: _ArmPainter(
                  beat: _beat,
                  flutes: _flutes,
                  heat: _heat,
                  layer: widget.game.sim.layer.value,
                  // The arm on screen IS the arm being bought. Every mark
                  // shows up as metal on the piece it belongs to, so the
                  // player watches the machine grow rather than a counter.
                  bitMark: widget.game.sim.bitMark.value,
                  driveMark: widget.game.sim.driveMark.value,
                  supplyMark: widget.game.sim.supplyMark.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArmPainter extends CustomPainter {
  _ArmPainter({
    required this.beat,
    required this.flutes,
    required this.heat,
    required this.layer,
    required this.bitMark,
    required this.driveMark,
    required this.supplyMark,
  }) : _bit = BitPainter(flutes: flutes, bite: heat),
       _shank = PipePainter(flutes: flutes),
       _stones = StonePainter(layer: layer, thick: false),
       // A face that has been worked a while, so it reads as rock under a
       // hammer rather than a fresh slab. Cosmetic: the diagram is not tied
       // to the metre's real damage.
       _cracks = CrackPainter(0.3, layer: layer),
       super(repaint: Listenable.merge([beat, flutes, heat]));

  final ValueListenable<ArmBeat> beat;
  final ValueListenable<double> flutes;
  final ValueListenable<double> heat;

  /// The metre the player is standing on, so the face here is the face there.
  final int layer;

  /// The generation each piece is built to, 0 (Mk I) through 4 (Mk V).
  final int bitMark;
  final int driveMark;
  final int supplyMark;

  final BitPainter _bit;
  final PipePainter _shank;
  final StonePainter _stones;
  final CrackPainter _cracks;

  /// The drawing is authored at this width and scaled to whatever it gets.
  static const double _designWidth = 384;
  static const double _designHeight = ArmDiagram.designHeight;
  static const double _faceTop = 74;

  /// The wrist at rest, and how far down the head hangs from it.
  static const double _wristRest = 36;
  static const double _shankLength = 10;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // One scale for both axes: a schematic scaled unevenly turns its callout
    // circles into eggs, which is exactly what happened the first time.
    //
    // Anchored to the BOTTOM rather than centred: the rock has to meet the
    // frame's lower edge, and centring split the scaling slack into a hairline
    // above and a hairline of empty below the face. Whatever slack is left now
    // lands at the top, where the borehole backdrop already is.
    final scale = size.width / _designWidth;
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    // Anchored to the TOP now, with the rock running on to whatever bottom
    // it is given. Bottom-anchoring was right while the band was a box of
    // exactly the authored height; a band that can be taller than the arm
    // would push the arm down and leave the borehole a sliver.
    final bottom = math.max(size.height / scale, _designHeight);

    final now = beat.value;
    _paintFace(canvas, bottom);
    _paintArm(canvas, now);
    _paintCallouts(canvas, now);

    canvas.restore();
  }

  /// The face is the mine's own layer: the stratum's gradient, then the
  /// texture and the ore [StonePainter] salts it with.
  void _paintFace(Canvas canvas, double bottom) {
    // Run the face a little past the bottom of the band: a fraction of a
    // pixel of rounding must never read as a gap under the rock.
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

  void _paintArm(Canvas canvas, ArmBeat beat) {
    // A kinematic chain rather than one rigid piece: the shoulder barely
    // stirs, the elbow gives, the wrist carries the whole stroke.
    final plunge = beat.plunge;
    final shoulder = plunge * 0.12;
    final elbow = plunge * 0.4;

    final housing = RRect.fromRectAndRadius(
      Rect.fromLTWH(322, 6 + shoulder, 50, 32),
      const Radius.circular(6),
    );
    canvas.drawRRect(housing, Paint()..color = Palette.card);
    canvas.drawRRect(
      housing,
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final bolt in const [Offset(331, 14), Offset(363, 14)]) {
      canvas.drawCircle(
        bolt.translate(0, shoulder),
        1.9,
        Paint()..color = Palette.edge,
      );
      canvas.drawCircle(
        bolt.translate(0, 16 + shoulder),
        1.9,
        Paint()..color = Palette.edge,
      );
    }
    // The pack's cells, one more with every mark it is rebuilt to.
    final cells = supplyMark + 2;
    for (var i = 0; i < cells; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(351, 11 + shoulder + i * 4.2, 9, 2.6),
          const Radius.circular(1.3),
        ),
        Paint()..color = Palette.gold.withValues(alpha: 0.85),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(338, 18 + shoulder)
        ..lineTo(346, 18 + shoulder)
        ..lineTo(342, 23 + shoulder)
        ..lineTo(347, 23 + shoulder)
        ..lineTo(339, 32 + shoulder)
        ..lineTo(342, 25 + shoulder)
        ..lineTo(336, 25 + shoulder)
        ..close(),
      Paint()..color = Palette.gold.withValues(alpha: 0.8),
    );

    final elbowAt = Offset(250, 29 + elbow);
    final wrist = Offset(176, _wristRest + plunge);

    _segment(canvas, Offset(328, 22 + shoulder), elbowAt.translate(2, 0), 17);
    _joint(canvas, elbowAt, 11.5);
    _segment(canvas, elbowAt.translate(-2, 2), wrist.translate(2, -1), 15);

    // Actuator: the drive lever's own piece, slung under the forearm.
    final rodFrom = Offset.lerp(elbowAt, wrist, 0.2)!.translate(0, 12);
    final rodTo = Offset.lerp(elbowAt, wrist, 0.74)!.translate(0, 12);
    canvas.drawLine(
      rodFrom,
      rodTo,
      Paint()
        ..color = Palette.lineBar
        ..strokeWidth = 9 + driveMark * 0.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      rodFrom,
      Offset.lerp(rodFrom, rodTo, 0.5)!,
      Paint()
        ..color = const Color(0xFF8794A6)
        ..strokeWidth = 6 + driveMark * 0.7
        ..strokeCap = StrokeCap.round,
    );
    // Ribs across the actuator: what a rebuilt drive puts on the outside.
    final along = rodTo - rodFrom;
    final across =
        Offset(-along.dy, along.dx) / along.distance * (4.5 + driveMark * 0.5);
    final ribs = driveMark + 2;
    for (var i = 1; i <= ribs; i++) {
      final at = Offset.lerp(rodFrom, rodTo, i / (ribs + 1))!;
      canvas.drawLine(
        at - across,
        at + across,
        Paint()
          ..color = Palette.edge
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    _joint(canvas, wrist, 10);

    // The rig's own shank and head, painted by the rig's own painters, so the
    // arm and the drills are visibly one machine.
    canvas.save();
    canvas.translate(wrist.dx - pipeWidth / 2, wrist.dy + 4);
    _shank.paint(canvas, const Size(pipeWidth, _shankLength));
    canvas.restore();

    // A collar per mark, stacked up the shank.
    for (var i = 0; i < bitMark; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            wrist.dx - pipeWidth / 2 - 1.6,
            wrist.dy + 5.2 + i * 2.4,
            pipeWidth + 3.2,
            1.7,
          ),
          const Radius.circular(0.8),
        ),
        Paint()..color = Palette.gold.withValues(alpha: 0.85),
      );
    }

    // Scaled about the TIP, not the shoulder: a bigger head has to keep
    // meeting the rock on the same line, or the sparks drift off the face.
    canvas.save();
    canvas.translate(wrist.dx, wrist.dy + 4 + _shankLength + bitHeight);
    canvas.scale(1 + bitMark * 0.05);
    canvas.translate(-bitWidth / 2, -bitHeight);
    _bit.paint(canvas, const Size(bitWidth, bitHeight));
    canvas.restore();
  }

  void _segment(Canvas canvas, Offset from, Offset to, double width) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF3E4854)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF7C8595)
        ..strokeWidth = width - 4.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from.translate(3, -4),
      to.translate(3, -4),
      Paint()
        ..color = const Color(0xD9C3CAD6)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _joint(Canvas canvas, Offset at, double radius) {
    canvas.drawCircle(at, radius, Paint()..color = Palette.edge);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = Palette.lineBar
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(at, radius * 0.38, Paint()..color = Palette.well);
  }

  /// One numbered marker per part, each riding the piece it names -- so the
  /// three travel with the arm instead of hanging in the air beside it.
  void _paintCallouts(Canvas canvas, ArmBeat beat) {
    final plunge = beat.plunge;
    final marks = [
      (
        Offset(176 - pipeWidth / 2, _wristRest + plunge + 18),
        Offset(136, _wristRest + plunge + 14),
        '1',
      ),
      (Offset(224, 48 + plunge * 0.55), Offset(236, 70 + plunge * 0.45), '2'),
      (Offset(347, 38 + plunge * 0.12), Offset(347, 60 + plunge * 0.12), '3'),
    ];
    for (final (from, at, label) in marks) {
      canvas.drawLine(
        from,
        at,
        Paint()
          ..color = Palette.amber.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(at, 8, Paint()..color = Palette.goldWell);
      canvas.drawCircle(
        at,
        8,
        Paint()
          ..color = Palette.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: AppText.display(
            9,
            weight: FontWeight.w700,
            color: Palette.gold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ArmPainter oldDelegate) =>
      oldDelegate.layer != layer ||
      oldDelegate.bitMark != bitMark ||
      oldDelegate.driveMark != driveMark ||
      oldDelegate.supplyMark != supplyMark;
}
