import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../floating_number_view.dart';

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
