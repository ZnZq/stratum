import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The per-frame ticker every animated scene used to spell out by hand:
/// one ticker, the last frame's stamp, the clamped delta. A scene mixes
/// this in and implements [onFrame]; the ticker's life follows the
/// state's.
///
/// [dt] is the CLAMPED delta in seconds (a muted ticker keeps counting,
/// and the first frame after a pause must not bring the whole pause);
/// [raw] is the unclamped gap, for scenes that must SNAP after a frame
/// hole rather than animate across it.
mixin FrameClock<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker frameTicker;
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    frameTicker = createTicker(_frame)..start();
  }

  void _frame(Duration elapsed) {
    final raw = elapsed - _lastFrame;
    _lastFrame = elapsed;
    onFrame(clampFrameDelta(raw).inMicroseconds / 1e6, raw);
  }

  void onFrame(double dt, Duration raw);

  @override
  void dispose() {
    frameTicker.dispose();
    super.dispose();
  }
}
