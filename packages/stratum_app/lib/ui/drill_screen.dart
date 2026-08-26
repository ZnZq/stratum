import 'package:flutter/widgets.dart';

import '../game.dart';
import 'drill/deck.dart';
import 'drill/overlays.dart';
import 'drill/rig.dart';
import 'drill/rock.dart';
import 'tokens.dart';

/// The borehole, seen in section, filling the screen.
///
/// The rock is the subject and everything else is glass laid over it: readouts
/// hug the edges, the drill keeps the middle channel, and the controls sit on a
/// deck that fades the rock out beneath them rather than boxing it in.
class DrillScreen extends StatelessWidget {
  const DrillScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.scene,
      child: Stack(
        children: [
          Positioned.fill(child: Rock(game: game)),
          ForcingGrip(game: game),
          Positioned.fill(child: DrillString(game: game)),
          Positioned.fill(child: FloatLayer(game: game)),
          Flash(
            trigger: game.breakFlashes,
            duration: const Duration(milliseconds: 550),
            peak: 0.85,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80FFD782), Color(0x14EF9F27)],
              ),
            ),
          ),
          Flash(
            trigger: game.criticalFlashes,
            duration: const Duration(milliseconds: 500),
            peak: 1,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 0.7,
                colors: [Color(0x80EF9F27), Color(0x00EF9F27)],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, child: DepthReadout(game: game)),
          Positioned(left: 0, right: 0, bottom: 0, child: Deck(game: game)),
        ],
      ),
    );
  }
}
