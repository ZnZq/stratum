import 'package:flutter/widgets.dart';

/// The lamp that opens a console line: the same green/amber/red the server
/// racks run on, so one glance tells whether a thing is idle, working or
/// spent -- wherever it appears.
class HudLamp extends StatelessWidget {
  const HudLamp({required this.colour, this.size = 5, super.key});

  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colour.withValues(alpha: 0.5), blurRadius: 5),
        ],
      ),
    );
  }
}
