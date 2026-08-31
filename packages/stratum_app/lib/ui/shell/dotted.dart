import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A small dot in the top-right corner of whatever it wraps.
class Dotted extends StatelessWidget {
  const Dotted({required this.marked, required this.child, super.key});

  final bool marked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!marked) return child;
    return Stack(
      clipBehavior: Clip.none,
      // Passthrough, not the default loose fit: a tab in an Expanded is given
      // a tight width, and loosening it would let the marked one shrink to
      // its own size while its unmarked neighbours filled their share.
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Palette.tech,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.page, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
