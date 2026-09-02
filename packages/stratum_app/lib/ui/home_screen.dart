import 'package:flutter/widgets.dart';

import '../game.dart';
import 'ai_sphere.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'navigation.dart';
import 'shell/dotted.dart';
import 'tokens.dart';

/// The shell of a world, and the one round button that crosses to the
/// other.
///
/// What is left when the player steps out of every section. The
/// simulation's home keeps the game's name over the drifting field; the
/// centre's shows the AI itself -- the sphere, drawn from the run's
/// numbers. The crossing sits in the same corner of both, so the two
/// homes mirror each other, and it is the only thing here that can be
/// pressed: it is not a place in this world but the door out of it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.game,
    required this.world,
    required this.marked,
    required this.onCross,
    super.key,
  });

  final Game game;
  final GameWorld world;

  /// Whether the other world has something to act on: the crossing carries
  /// the dot, since it is the only way there.
  final bool marked;

  final VoidCallback onCross;

  /// The palette the rays are dealt from: the game's own inks, each the
  /// colour of something the model has learned.
  static const List<Color> _inks = [
    Palette.tech,
    Palette.gold,
    Palette.steel,
    Palette.quantonium,
    Palette.sample,
    Palette.credit,
    Palette.crystal,
    Palette.alarm,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: switch (world) {
              GameWorld.simulation => Text(
                world.title,
                style: AppText.display(
                  22,
                  weight: FontWeight.w700,
                  color: const Color(0x667FD9C4),
                  letterSpacing: 11,
                ),
              ),
              GameWorld.centre => _portrait(),
            },
          ),
        ),
        Positioned(
          right: 14,
          bottom: AppMetrics.navBar + 10,
          child: _CrossButton(world: world, marked: marked, onTap: onCross),
        ),
      ],
    );
  }

  /// How many filaments a young AI throws. The sphere is meant to grow
  /// with the simulation tree (owner, 2026-09-03): a bought node will add
  /// its ray in its branch's colour, so until the tree exists the count
  /// stays small and the picture has room to become.
  static const int _seedRays = 12;

  /// The AI as the run has made it: the seed rays for now (the tree will
  /// add to them), and a core that swells with the model against its
  /// first server.
  Widget _portrait() {
    final sim = game.sim;
    final now = DateTime.now().millisecondsSinceEpoch;
    const rays = _seedRays;
    final capacity = sim.collapseThreshold(now).toDouble();
    final pressure = capacity > 0
        ? (sim.modelMemory.toDouble() / capacity).clamp(0.0, 1.0)
        : 0.0;
    return AiSphere(rays: rays, pressure: pressure, colours: _inks);
  }
}

/// The round crossing: a seated disc with the other world's glyph.
class _CrossButton extends StatelessWidget {
  const _CrossButton({
    required this.world,
    required this.marked,
    required this.onTap,
  });

  final GameWorld world;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (world) {
      GameWorld.simulation => Ic.datacentre,
      GameWorld.centre => Ic.mine,
    };
    return Semantics(
      label: world.crossing,
      button: true,
      child: Dotted(
        marked: marked,
        child: ClipOval(
          child: HudTap(
            onTap: onTap,
            corners: HudCorners.none,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.well,
                border: Border.all(
                  color: Palette.gold.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Center(
                child: GameIcon(icon, size: 21, colour: Palette.gold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
