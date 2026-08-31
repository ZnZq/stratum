import 'package:flutter/widgets.dart';

import '../tokens.dart';

import 'dart:async';

/// How long a mode has been held, ticking once a second.
///
/// Driven by a plain [Timer], not a Ticker: both overlays live where
/// TickerMode is off or the scene is meant to be still, and a frame-rate
/// clock for a once-a-second digit would be waste anyway.
class SinceClock extends StatefulWidget {
  const SinceClock({
    required this.since,
    required this.prefix,
    required this.color,
    super.key,
  });

  final DateTime since;
  final String prefix;
  final Color color;

  @override
  State<SinceClock> createState() => _SinceClockState();
}

class _SinceClockState extends State<SinceClock> {
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    _beat = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  static String _clock(Duration span) {
    String two(int value) => value.toString().padLeft(2, '0');
    if (span.inHours > 0) {
      return '${span.inHours}:${two(span.inMinutes % 60)}:'
          '${two(span.inSeconds % 60)}';
    }
    return '${two(span.inMinutes)}:${two(span.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final held = DateTime.now().difference(widget.since);
    return Text(
      '${widget.prefix} ${_clock(held < Duration.zero ? Duration.zero : held)}',
      style: AppText.display(
        13,
        weight: FontWeight.w600,
        color: widget.color,
        shadows: true,
      ),
    );
  }
}
