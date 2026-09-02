import 'package:flutter/widgets.dart';

import '../../game.dart';

import 'package:stratum_core/stratum_core.dart';

import 'hit_shake.dart';
import 'layer_tile.dart';
import 'metrics.dart';

class Rock extends StatelessWidget {
  const Rock({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: game.sim.layer.value.toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, position, _) =>
            _build(constraints.maxHeight, position),
      ),
    );
  }

  Widget _build(double height, double position) {
    final sim = game.sim;
    final current = sim.layer.value;

    // The window of rendered layers follows the animated position, and the
    // camera offset is measured from the first of them. As the position crosses
    // an integer the window steps down and the offset steps back by exactly as
    // much, so the two cancel and the descent stays continuous instead of
    // restarting every metre.
    //
    // Every metre is one [layerHeight] tall whether or not it is its own
    // layer, which is what lets the offset be a plain multiplication: a thick
    // layer is one tile three metres tall, not a tall single metre.
    final first = PrototypeSimulation.layerStart(position.floor());
    final travelled = (position - first) * layerHeight;

    var last = current;
    var tiles = 0;
    var filled = 0.0;
    while ((filled < height || tiles < layersBelow) && tiles < 64) {
      last = PrototypeSimulation.nextLayer(last);
      filled += heightOf(last);
      tiles++;
    }

    // Effort space, not hp: half a bar means half the blows are behind
    // you, matching the hits-to-break readout instead of contradicting it.
    final hpFraction = 1 - sim.layerEffort.value;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // Applied straight, with no tween of its own: the offset steps by a
          // whole layer at each crossing, and that step is exactly what the
          // shifted window of layers cancels out. Easing it would undo the
          // cancellation and make the descent lurch.
          child: Transform.translate(
            offset: Offset(0, rockTop - travelled),
            child: Column(
              children: [
                for (
                  var i = first;
                  i <= last;
                  i = PrototypeSimulation.nextLayer(i)
                )
                  SizedBox(
                    height: heightOf(i),
                    child: i == current
                        ? HitShake(
                            trigger: game.hitShakes,
                            child: LayerTile(
                              layer: i,
                              isCurrent: true,
                              isPast: false,
                              hpFraction: hpFraction,
                            ),
                          )
                        // Only the face being dug shows damage; the rest
                        // must not reconfigure on every hit.
                        : LayerTile(
                            layer: i,
                            isCurrent: false,
                            isPast: i < current,
                            hpFraction: 1,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
