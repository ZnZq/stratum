import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The shell the screens are laid on.
///
/// Deliberately empty of content and not empty of life: a flat fill behind a
/// floating island reads as a rendering fault, while a slow field reads as a
/// room the islands are in. The content of the shell state is [HomeScreen],
/// laid over this.
class ShellBackdrop extends StatefulWidget {
  const ShellBackdrop({super.key});

  @override
  State<ShellBackdrop> createState() => _ShellBackdropState();
}

class _ShellBackdropState extends State<ShellBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final delta = clampFrameDelta(elapsed - _lastFrame);
    _lastFrame = elapsed;
    _time.value += delta.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.page,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: CustomPaint(painter: _ShellPainter(_time))),
        ],
      ),
    );
  }
}

class _ShellPainter extends CustomPainter {
  _ShellPainter(this.time) : super(repaint: time);

  final ValueListenable<double> time;

  static const int _motes = 34;
  static const double _grid = 58;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.clipRect(Offset.zero & size);

    // A cold pool of light behind the islands, so their edges have something
    // to stand against instead of dissolving into the fill.
    final centre = Offset(size.width / 2, size.height * 0.42);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader =
            RadialGradient(colors: const [Color(0x1F7FD9C4), Color(0x00000000)])
                .createShader(
                  Rect.fromCircle(center: centre, radius: size.width * 0.95),
                ),
    );

    // A slow lattice, drifting far more gently than the shaft's: the shell is
    // not descending, so nothing here should look like it is.
    final rule = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x0FA8C4E0);
    final drift = (t * 3) % _grid;
    for (var y = size.height - drift; y > -_grid; y -= _grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    for (var x = -_grid + drift; x < size.width + _grid; x += _grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), rule);
    }

    // Motes, each derived from its index so the field needs no state between
    // frames and never restarts.
    for (var i = 0; i < _motes; i++) {
      final seed = i * 0.6180339887;
      final span = size.height + 60;
      final speed = 5 + ((seed * 11.7) % 1.0) * 13;
      final y = span - ((t * speed + seed * span * 3) % span);
      final x = ((seed * 7.3) % 1.0) * size.width + math.sin(t * 0.25 + i) * 9;
      final fade = 0.06 + ((seed * 3.3) % 1.0) * 0.14;
      canvas.drawCircle(
        Offset(x, y),
        0.6 + ((seed * 5.7) % 1.0) * 1.3,
        Paint()..color = Color.fromRGBO(190, 220, 235, fade),
      );
    }
  }

  @override
  bool shouldRepaint(_ShellPainter oldDelegate) => false;
}
