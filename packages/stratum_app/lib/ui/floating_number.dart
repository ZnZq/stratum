import 'package:flutter/widgets.dart';

import '../game.dart';
import 'tokens.dart';

/// A number that rises out of the scene and fades, then removes itself.
///
/// Each one owns its animation so the scene keeps no bookkeeping: the widget
/// tells the game to forget it when the flight is over.
class FloatingNumberView extends StatefulWidget {
  const FloatingNumberView({
    required this.number,
    required this.onDone,
    super.key,
  });

  final FloatingNumber number;
  final VoidCallback onDone;

  @override
  State<FloatingNumberView> createState() => _FloatingNumberViewState();
}

class _FloatingNumberViewState extends State<FloatingNumberView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Rises through the whole flight, fades in fast and out slowly, which
        // is what the prototype's keyframes do.
        final opacity = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;
        return Positioned(
          left: widget.number.left,
          top: widget.number.top + 10 - t * 68,
          child: Opacity(opacity: opacity.clamp(0, 1), child: child),
        );
      },
      child: Text(
        widget.number.text,
        maxLines: 1,
        style: AppText.display(
          widget.number.size,
          color: Color(widget.number.color),
          shadows: true,
        ),
      ),
    );
  }
}
