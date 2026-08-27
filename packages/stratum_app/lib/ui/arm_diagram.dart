import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The manipulator arm, mid-blow, with its three upgradeable parts called out.
///
/// A schematic rather than scenery: its job is to say which part each lever
/// belongs to, so the numbered callouts here and the numbered wells on the
/// cards below are the same three numbers.
class ArmDiagram extends StatelessWidget {
  const ArmDiagram({super.key});

  static const double _height = 110;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: Palette.shell,
          border: Border.all(color: Palette.lineBar),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CustomPaint(painter: _ArmPainter()),
      ),
    );
  }
}

class _ArmPainter extends CustomPainter {
  const _ArmPainter();

  /// The drawing is authored at this width and scaled to whatever it gets.
  static const double _designWidth = 384;
  static const double _designHeight = 110;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _designWidth, size.height / _designHeight);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _designWidth, _designHeight));

    _paintFace(canvas);
    _paintArm(canvas);
    _paintImpact(canvas);
    _paintCallouts(canvas);

    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    const band = Rect.fromLTWH(0, 84, _designWidth, 26);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B8589), Color(0xFF3E5257)],
        ).createShader(band),
    );
    canvas.drawLine(
      const Offset(0, 84),
      const Offset(_designWidth, 84),
      Paint()
        ..color = const Color(0xFF2A3A3E)
        ..strokeWidth = 2,
    );

    final crack = Paint()
      ..color = const Color(0xFF22312F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final path in const [
      [Offset(46, 90), Offset(64, 100), Offset(57, 108)],
      [Offset(262, 92), Offset(282, 100), Offset(276, 110)],
      [Offset(330, 88), Offset(318, 102)],
    ]) {
      final line = Path()..moveTo(path.first.dx, path.first.dy);
      for (final point in path.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(line, crack);
    }
  }

  void _paintArm(Canvas canvas) {
    // Shoulder housing: the pack the supply lever belongs to.
    final housing = RRect.fromRectAndRadius(
      const Rect.fromLTWH(322, 4, 50, 32),
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
    for (final bolt in const [
      Offset(331, 12),
      Offset(363, 12),
      Offset(331, 28),
      Offset(363, 28),
    ]) {
      canvas.drawCircle(bolt, 1.9, Paint()..color = Palette.edge);
    }
    canvas.drawPath(
      Path()
        ..moveTo(338, 16)
        ..lineTo(346, 16)
        ..lineTo(342, 21)
        ..lineTo(347, 21)
        ..lineTo(339, 30)
        ..lineTo(342, 23)
        ..lineTo(336, 23)
        ..close(),
      Paint()..color = Palette.gold.withValues(alpha: 0.8),
    );

    _segment(canvas, const Offset(328, 20), const Offset(252, 28), 17);
    _joint(canvas, const Offset(250, 28), 11.5);
    _segment(canvas, const Offset(248, 30), const Offset(178, 45), 15);

    // Actuator: the drive lever's own piece, slung under the forearm.
    canvas.drawLine(
      const Offset(238, 43),
      const Offset(198, 52),
      Paint()
        ..color = Palette.lineBar
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(234, 44),
      const Offset(212, 49),
      Paint()
        ..color = const Color(0xFF8794A6)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    _joint(canvas, const Offset(176, 46), 10);

    // The bit: the same head the rig's strings carry.
    const shank = Rect.fromLTWH(165, 51, 22, 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shank, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF171A21),
            Color(0xFFC3CAD6),
            Color(0xFF7C8595),
            Color(0xFF14171D),
          ],
          stops: [0, 0.34, 0.7, 1],
        ).createShader(shank),
    );
    final flute = Paint()
      ..color = const Color(0x38000000)
      ..strokeWidth = 2.8;
    canvas.drawLine(const Offset(165, 58), const Offset(187, 64), flute);
    canvas.drawLine(const Offset(165, 69), const Offset(187, 75), flute);
    canvas.drawPath(
      Path()
        ..moveTo(165, 79)
        ..lineTo(187, 79)
        ..lineTo(176, 97)
        ..close(),
      Paint()..color = const Color(0xFFC3CAD6),
    );
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

  void _paintImpact(Canvas canvas) {
    const centre = Offset(176, 87);
    final glow = Rect.fromCenter(center: centre, width: 100, height: 44);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE9B0).withValues(alpha: 0.95),
            const Color(0x00EF9F27),
          ],
        ).createShader(glow),
    );
    final spark = Paint()
      ..color = const Color(0xFFFFE9B0)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final end in const [
      Offset(-23, -14),
      Offset(23, -14),
      Offset(-34, -2),
      Offset(34, -2),
    ]) {
      canvas.drawLine(centre, centre + end, spark);
    }
    canvas.drawCircle(centre, 5.4, Paint()..color = const Color(0xFFFFF6DE));
  }

  /// One numbered marker per part, tied to the piece it names by a leader.
  void _paintCallouts(Canvas canvas) {
    const marks = [
      (Offset(176, 66), Offset(140, 57), '1'),
      (Offset(222, 47), Offset(236, 68), '2'),
      (Offset(347, 36), Offset(347, 54), '3'),
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
  bool shouldRepaint(_ArmPainter oldDelegate) => false;
}
