import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
