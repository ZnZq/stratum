import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../game_icons.dart';
import '../stat.dart';
import '../tokens.dart';

import 'dart:math' as math;

import 'package:stratum_core/stratum_core.dart';

import 'energy_meter.dart';

/// The charge, as a plate with its own bar under it.
///
/// The number says where the gauge stands and the bar says the same thing in
/// one glance; the pale sliver at the bar's edge is the point currently being
/// earned, so the rhythm the label states in words is also visible.
class EnergyPlate extends StatelessWidget {
  const EnergyPlate({required this.game, super.key});

  final Game game;

  static const double _width = 142;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final spent = sim.energy.value < PrototypeSimulation.strikeCost;

    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stat(
            label: 'енергія',
            icon: Ic.energy,
            align: CrossAxisAlignment.end,
            shadows: true,
            // Two styles in one figure, so the gauge passes a child rather
            // than a string: the points stand out, the cap stays quiet.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _EnergyCount(
                  value: sim.energy.value,
                  style: AppText.display(
                    Stat.valueSize,
                    weight: FontWeight.w700,
                    color: spent ? Palette.textFaint : Palette.textDim,
                    shadows: true,
                  ),
                ),
                Text(
                  ' / ${sim.energyCap}',
                  style: AppText.display(
                    9.5,
                    color: Palette.textFaint,
                    shadows: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          EnergyMeter(engine: game.energyLoop, full: sim.energyFull),
          const SizedBox(height: 4),
          Text(
            '+${sim.energyPerRegen} / ${game.energyInterval}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.body(
              8.5,
              weight: FontWeight.w600,
              letterSpacing: 0.6,
              color: spent ? Palette.textFaint : Palette.tech,
              shadows: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// The energy figure, flinching whenever it moves.
///
/// A swell when a point lands, a shorter dip when a strike spends one, so the
/// two directions are told apart without reading the number. Transform.scale
/// is paint only, so the plate never resizes and the row never shifts; and
/// the pulse rides its own controller rather than a keyed tween, because at
/// ten strikes a second the changes outrun the animation and a restart from
/// rest is what keeps that legible instead of jittery.
class _EnergyCount extends StatefulWidget {
  const _EnergyCount({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  State<_EnergyCount> createState() => _EnergyCountState();
}

class _EnergyCountState extends State<_EnergyCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  );

  /// How far and which way the current pulse swells.
  double _swell = 0;

  @override
  void didUpdateWidget(_EnergyCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    _swell = widget.value > oldWidget.value ? 0.15 : -0.1;
    _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + _swell * math.sin(math.pi * _pulse.value),
        child: child,
      ),
      child: Text('${widget.value}', style: widget.style),
    );
  }
}
