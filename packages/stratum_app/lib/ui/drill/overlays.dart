/// Everything the scene throws over itself: the depth readout, the numbers
/// that float off a cycle, and the flashes a crit or a break sets off.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../../game.dart';
import '../floating_number.dart';
import '../tokens.dart';

/// Depth, set into the top-left corner clear of the drill's channel.
class DepthReadout extends StatelessWidget {
  const DepthReadout({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, AppMetrics.resourceBar + 4, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'симуляція ${sim.restarts.value + 1}',
            style: AppText.body(
              9,
              color: Palette.textMuted,
              letterSpacing: 2.4,
              shadows: true,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                sim.layer.value.big.toString(NumberStyle.integer),
                style: AppText.display(
                  44,
                  color: Palette.gold,
                  height: 1,
                  shadows: true,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'м',
                style: AppText.display(16, color: Palette.gold, shadows: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FloatLayer extends StatelessWidget {
  const FloatLayer({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final float in game.floats)
            FloatingNumberView(
              key: ValueKey(float.id),
              number: float,
              onDone: () => game.retireFloat(float.id),
            ),
        ],
      ),
    );
  }
}

/// A one-shot wash of colour over the scene, replayed whenever [trigger] moves.
class Flash extends StatefulWidget {
  const Flash({
    required this.trigger,
    required this.duration,
    required this.peak,
    required this.decoration,
    super.key,
  });

  final ValueListenable<int> trigger;
  final Duration duration;
  final double peak;
  final Decoration decoration;

  @override
  State<Flash> createState() => FlashState();
}

class FlashState extends State<Flash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_play);
  }

  void _play() => _controller.forward(from: 0);

  @override
  void dispose() {
    widget.trigger.removeListener(_play);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final opacity = t < 0.2
                ? t / 0.2 * widget.peak
                : (1 - t) / 0.8 * widget.peak;
            return Opacity(opacity: opacity.clamp(0, 1), child: child);
          },
          child: DecoratedBox(decoration: widget.decoration),
        ),
      ),
    );
  }
}
