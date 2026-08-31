import 'package:flutter/widgets.dart';

import '../gauge.dart';
import '../tokens.dart';

/// The strip's round gauge, chasing its own money.
///
/// New income lands in a pale lane INSTANTLY; the credit-green fill then
/// animates up to it. Two frames of truth on one track: where you are, and
/// what just arrived -- the chase is what makes a sale feel banked.
class RoundGauge extends StatefulWidget {
  const RoundGauge({required this.round, required this.target, super.key});

  /// The round the bar is filling. A change means the ladder rolled over:
  /// the fill snaps to zero and climbs the new rung rather than easing
  /// backwards through it.
  final int round;

  final double target;

  @override
  State<RoundGauge> createState() => _RoundGaugeState();
}

class _RoundGaugeState extends State<RoundGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chase;

  @override
  void initState() {
    super.initState();
    _chase = AnimationController(vsync: this, value: widget.target);
  }

  @override
  void didUpdateWidget(RoundGauge old) {
    super.didUpdateWidget(old);
    if (widget.round != old.round) _chase.value = 0;
    if (_chase.value != widget.target) {
      // The duration is EXPLICIT because animateTo without one scales the
      // controller's duration by the remaining distance -- a small sale got
      // a chase of eighty milliseconds and read as a plain jump. Measured,
      // not guessed: the diagnostics log said "done" 83 ms after the start.
      _chase.animateTo(
        widget.target,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _chase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A POUR, not cells: money is continuous, and a cell lane swallowed any
    // arrival smaller than one cell -- the chase was real and invisible.
    // Two gauges on one track: the pale one snaps to what just arrived, the
    // credit-green one rides the controller frame by frame underneath it.
    return SizedBox(
      height: 14,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Near-white, not a lighter green: the two lanes sit on a
          // 14-px strip, and two light greens read as one -- caught on a
          // frame grab, present and invisible at once.
          Gauge(
            fraction: widget.target,
            height: 14,
            radius: 0,
            fill: Palette.text,
          ),
          Gauge.live(
            value: _chase,
            height: 14,
            radius: 0,
            track: const Color(0x00000000),
            fill: Palette.credit,
          ),
        ],
      ),
    );
  }
}
