import 'package:flutter/widgets.dart';

import '../../game.dart';
import 'metrics.dart';
import 'depth_readout.dart';
import 'bit.dart';
import 'energy_plate.dart';
import 'pipe.dart';

/// The drill string and the bit, with the readouts in a band above them.
///
/// No cycle clock here, neither the ring around the string nor a figure in the
/// band: every drill will keep its own cadence once they are typed, so one
/// number over the whole rig would be a lie the moment the second kind of
/// drill arrives. What a drill is doing belongs on that drill's own card.
class DrillString extends StatelessWidget {
  const DrillString({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;

    return IgnorePointer(
      child: Stack(
        children: [
          // Every readout in one band above the rig. The rig is a row across
          // the whole face now, so there is no longer a side of it to stand
          // beside, and the numbers would be drilled through.
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DepthReadout(game: game),
                const Spacer(),
                EnergyPlate(game: game),
              ],
            ),
          ),
          // One column per drill, spread across the face. Each runs a hair out
          // of phase with its neighbour, so a row of them reads as machinery
          // rather than as one drill stamped seven times.
          Positioned(
            top: headTop,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < drawnDrills(sim.drills.value); i++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DrillPipe(phase: i * 0.13),
                      DrillBit(engine: game.drill, phase: i * 0.13),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
