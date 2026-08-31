import 'package:flutter/widgets.dart';

/// The fade a scrolling list makes into the shell floor. Only lawful over
/// a surface with its own backdrop (the rock, the manipulator bay): the
/// gradient ends in the shell colour and needs that floor to land on.
class Dissolve extends StatelessWidget {
  const Dissolve({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x001D2734), Color(0xE01D2734), Color(0xFF1D2734)],
            stops: [0, 0.62, 1],
          ),
        ),
      ),
    );
  }
}
