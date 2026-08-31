import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../gauge.dart';
import '../tokens.dart';

import 'package:flutter/scheduler.dart';

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
      child: Gauge.live(
        value: _progress,
        height: 2,
        track: const Color(0x66000000),
        // Gold once the gauge is full: the sweep has nowhere to land, so the
        // bar stands still and says "at the cap" instead.
        gradient: LinearGradient(
          colors: widget.full
              ? const [Palette.gold, Palette.gold]
              : const [Palette.tech, Palette.compute],
        ),
      ),
    );
  }
}
