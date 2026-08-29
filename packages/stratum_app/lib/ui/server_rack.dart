import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'resource_style.dart';
import 'tokens.dart';

/// One server rack, drawn wherever it is put.
///
/// A rack is the game's unit of collapse, so it is a widget rather than a
/// stretch of some larger painter: the Data Centre lines five of them up, but
/// a collapse dialog, a tooltip or a tutorial can show a single one at any
/// size without reproducing the wall's geometry.
///
/// It carries its own clock. Five tickers for five racks is a trade made on
/// purpose -- a rack handed a clock from outside is a rack that cannot be
/// dropped into a screen without wiring.
class ServerRack extends StatefulWidget {
  const ServerRack({
    required this.fill,
    this.cost,
    this.slots = 7,
    this.slotHeight = 11,
    this.phase = 0,
    super.key,
  });

  /// How full this rack is, 0 to 1. At 1 it IS a collapse, and says so.
  final double fill;

  /// What it holds when full, already formatted. Written under the rack with
  /// the cubes glyph, so the figure needs no unit spelled after it. Null
  /// leaves the caption off.
  final String? cost;

  final int slots;

  /// How tall one slot is drawn. A rack sizes ITSELF from this rather than
  /// filling whatever box it is handed: a slot squeezed to seven pixels stops
  /// reading as a machine, and a caller should not have to know the height at
  /// which that happens.
  final double slotHeight;

  /// Desyncs the lamps from a neighbouring rack's.
  final int phase;

  /// The room the body asks for, before the caption.
  double get bodyHeight => slots * slotHeight + _padding * 2;

  /// Air inside the frame, above the first slot and below the last.
  static const double _padding = 5;

  @override
  State<ServerRack> createState() => _ServerRackState();
}

class _ServerRackState extends State<ServerRack>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final delta = clampFrameDelta(elapsed - _lastFrame).inMicroseconds / 1e6;
      _lastFrame = elapsed;
      _clock.value = _clock.value + delta;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.fill >= 1;
    final ink = full ? Palette.alarm : Palette.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.bodyHeight,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RackPainter(
                clock: _clock,
                fill: widget.fill.clamp(0.0, 1.0),
                slots: widget.slots,
                phase: widget.phase,
              ),
            ),
          ),
        ),
        if (widget.cost case final cost?) ...[
          const SizedBox(height: 5),
          // Icon and figure share one colour: they are one statement, and a
          // full rack turns both red at once.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CubesIcon(size: 11),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  cost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(
                    8.5,
                    weight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RackPainter extends CustomPainter {
  _RackPainter({
    required this.clock,
    required this.fill,
    required this.slots,
    required this.phase,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final double fill;
  final int slots;
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final spent = fill * slots;
    final done = fill >= 1;

    // A rack whose every slot is spent IS a collapse, ready to be taken. Its
    // frame says so, because that is the one thing the player can act on.
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF222D3B));
    canvas.drawRRect(
      body,
      Paint()
        ..color = done ? Palette.alarm : Palette.lineBar
        ..style = PaintingStyle.stroke
        ..strokeWidth = done ? 1.5 : 1,
    );

    final slotH = (size.height - 10) / slots;
    for (var s = 0; s < slots; s++) {
      final y = 5 + s * slotH;
      final slot = RRect.fromRectAndRadius(
        Rect.fromLTWH(4, y + 1, size.width - 8, slotH - 3),
        const Radius.circular(1.5),
      );

      // Every slot is drawn, always, the same. The rack is the machine, not
      // the gauge; what the gauge says lives in the lamps.
      canvas.drawRRect(slot, Paint()..color = const Color(0xFF1A2330));

      final lineY = y + slotH / 2 - 1;
      final lineW = (size.width - 18) * 0.6;
      canvas.drawRect(
        Rect.fromLTWH(6, lineY, lineW, 1),
        Paint()..color = Palette.lineBar,
      );

      // Green while there is room, red once the slot is spent, amber for the
      // one filling now -- so saturation reads as capacity being lost rather
      // than as progress being made, which is what it is.
      final taken = s < spent.floor();
      final filling = s == spent.floor() && spent % 1 > 0;
      final blink = 0.5 + 0.5 * math.sin(t * 3.1 + s * 0.7 + phase * 1.3);

      if (filling) {
        canvas.drawRect(
          Rect.fromLTWH(6, lineY, lineW * (spent % 1), 1),
          Paint()..color = Palette.amber,
        );
      }

      final lamp = taken
          ? Palette.alarm
          : filling
          ? Palette.amber
          : Palette.tech;
      // A spent lamp is steady, a working one breathes, a filling one pulses
      // hardest: the eye finds the frontier without being told.
      final alpha = taken
          ? 0.85
          : filling
          ? 0.55 + 0.45 * blink
          : 0.3 + 0.35 * blink;
      canvas.drawCircle(
        Offset(size.width - 7, y + slotH / 2 - 0.5),
        1.8,
        Paint()..color = lamp.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RackPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.slots != slots ||
      oldDelegate.phase != phase;
}
