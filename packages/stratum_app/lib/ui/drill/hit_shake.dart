import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dart:math' as math;

/// A short shudder every time the face takes a blow.
///
/// Keyed by the trigger count, so each hit restarts the jolt from full and a
/// burst of strikes reads as a rattle rather than one long wobble. Decay is in
/// the amplitude: the tile always comes to rest exactly where it was.
class HitShake extends StatelessWidget {
  const HitShake({required this.trigger, required this.child, super.key});

  final ValueListenable<int> trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: trigger,
      builder: (context, count, child) {
        if (count == 0) return child!;
        return TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (context, t, child) {
            final calm = 1 - t;
            return Transform.translate(
              offset: Offset(
                math.sin(t * math.pi * 4) * 2.6 * calm,
                math.sin(t * math.pi * 3 + 1) * 1.4 * calm,
              ),
              child: child,
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
