import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// What is behind the rig: the emptiness the drill has already cut.
///
/// Drilled rock is not drawn, so without this the top third of the screen is a
/// flat fill. This gives it depth instead of detail -- dust rising past the
/// string, a survey grid drifting with the descent, and a cold glow down the
/// hole -- so the eye reads a shaft rather than a background.
///
/// Everything moves upward, because the rig is going down.
class ShaftBackdrop extends StatefulWidget {
  const ShaftBackdrop({required this.forcing, super.key});

  /// Forcing doubles the pace, so the dust reacts to it too.
  final bool forcing;

  @override
  State<ShaftBackdrop> createState() => _ShaftBackdropState();
}

class _ShaftBackdropState extends State<ShaftBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;
    _time.value += delta.inMicroseconds / 1e6 * (widget.forcing ? 2.4 : 1);
  }

  Duration _lastFrame = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: CustomPaint(painter: _ShaftPainter(_time)));
  }
}

class _ShaftPainter extends CustomPainter {
  _ShaftPainter(this.time) : super(repaint: time);

  final ValueListenable<double> time;

  static const int _motes = 46;
  static const double _gridSpacing = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.clipRect(Offset.zero & size);

    // Cold light coming up out of the hole, so the middle is not as flat as
    // the edges and the rig has something to stand against.
    final glow = Offset(size.width / 2, size.height * 0.34);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x2E7FD9C4), Color(0x00000000)],
        ).createShader(Rect.fromCircle(center: glow, radius: size.width * 0.8)),
    );

    // A survey grid drifting up past the rig. Verticals stay put -- they read
    // as the shaft's own walls -- while the horizontals carry the motion.
    final rule = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x14A8C4E0);
    final drift = (t * 9) % _gridSpacing;
    for (var y = size.height - drift; y > -_gridSpacing; y -= _gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final wall = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x0DA8C4E0);
    for (final x in [size.width * 0.16, size.width * 0.84]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), wall);
    }

    // Dust: each mote has its own speed and phase, derived from its index, so
    // the field never needs storing between frames and never restarts.
    for (var i = 0; i < _motes; i++) {
      final seed = i * 0.6180339887;
      final x = ((seed * 7.3) % 1.0) * size.width;
      final speed = 12 + ((seed * 13.1) % 1.0) * 34;
      final span = size.height + 40;
      final y = span - ((t * speed + seed * span * 3) % span);
      final radius = 0.5 + ((seed * 5.7) % 1.0) * 1.5;
      final sway = math.sin(t * 0.7 + i) * 3;
      final fade = 0.10 + ((seed * 3.3) % 1.0) * 0.22;
      canvas.drawCircle(
        Offset(x + sway, y),
        radius,
        Paint()..color = Color.fromRGBO(190, 220, 235, fade),
      );
    }

    // The rock is lit from below by the bit, so the shaft darkens upward.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4D070A10), Color(0x00070A10)],
          stops: [0, 0.6],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ShaftPainter oldDelegate) => false;
}
