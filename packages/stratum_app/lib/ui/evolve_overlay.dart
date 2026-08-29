import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'arm_style.dart';
import 'game_icons.dart';
import 'game_modal.dart';
import 'hud.dart';
import 'part_glyph.dart';
import 'tokens.dart';

/// The moment a part is rebuilt into its next mark.
///
/// Evolution is the one thing on this screen that is not a purchase, so it
/// gets a beat of its own: the old face flashes out, the new one lands, and
/// the buffs the mark just switched on are read out. Anything the player had
/// to cross a hundred levels for is allowed to interrupt them.
class EvolveOverlay extends StatefulWidget {
  const EvolveOverlay({
    required this.part,
    required this.from,
    required this.to,
    required this.onClose,
    super.key,
  });

  final ArmPart part;

  /// The mark it wore, and the one it wears now.
  final int from;
  final int to;

  final VoidCallback onClose;

  @override
  State<EvolveOverlay> createState() => _EvolveOverlayState();
}

class _EvolveOverlayState extends State<EvolveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  /// Where the old face gives way to the new one.
  static const double _swap = 0.46;

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = armPartStyles[widget.part]!;
    final gained = buffsOpenedBy(widget.part, widget.to);

    return GameModal(
      icon: Ic.arm,
      title: 'ЕВОЛЮЦІЯ',
      accent: Palette.gold,
      inset: 24,
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Rebuild(
              play: _play,
              part: widget.part,
              from: widget.from,
              to: widget.to,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            style.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.body(
              10,
              weight: FontWeight.w700,
              color: Palette.textDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${markName(widget.from)} → ${markName(widget.to)}',
            textAlign: TextAlign.center,
            style: AppText.display(
              18,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
          const SizedBox(height: 12),
          _Gained(play: _play, gained: gained),
          const SizedBox(height: 12),
          HudButton(
            onTap: widget.onClose,
            label: 'ДАЛІ',
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ],
      ),
    );
  }
}

/// The face flashing out of its old mark and into the new one.
class _Rebuild extends StatelessWidget {
  const _Rebuild({
    required this.play,
    required this.part,
    required this.from,
    required this.to,
  });

  final Animation<double> play;
  final ArmPart part;
  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: play,
      builder: (context, _) {
        final t = play.value;
        final done = t >= _EvolveOverlayState._swap;

        // Three quickening pulses, then the swap, then the new face settles.
        final blink = done
            ? 1.0
            : 0.35 +
                  0.65 *
                      (0.5 +
                          0.5 *
                              math.cos(
                                t / _EvolveOverlayState._swap * math.pi * 6,
                              ));
        final pop = done
            ? 1 +
                  0.45 *
                      math.exp(-(t - _EvolveOverlayState._swap) * 14) *
                      math.cos((t - _EvolveOverlayState._swap) * 26)
            : 1.0;
        final flash = math.exp(-((t - _EvolveOverlayState._swap) * 9).abs());

        return SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Palette.gold.withValues(alpha: 0.55 * flash),
                      const Color(0x00EF9F27),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              Transform.scale(
                scale: pop,
                child: Opacity(
                  opacity: blink.clamp(0.0, 1.0),
                  child: PartFace(
                    part: part,
                    mark: done ? to : from,
                    lit: true,
                    size: 66,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the new mark switched on, arriving after the face has landed.
class _Gained extends StatelessWidget {
  const _Gained({required this.play, required this.gained});

  final Animation<double> play;
  final List<ArmBuff> gained;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: play,
      builder: (context, _) {
        final t = ((play.value - 0.62) / 0.3).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(
                color: Palette.well,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Palette.lineBar),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'НОВЕ В ЦЬОМУ ПОКОЛІННІ',
                    style: AppText.body(
                      8.5,
                      weight: FontWeight.w700,
                      color: Palette.tech,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (gained.isEmpty)
                    Text(
                      'нових бафів це покоління не додає — '
                      'зате стеля рівнів піднялась',
                      style: AppText.body(9.5, color: Palette.textFaint),
                    )
                  else
                    for (final buff in gained)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              buff.label,
                              style: AppText.body(10, color: Palette.textDim),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              buff.step,
                              style: AppText.display(9.5, color: Palette.gold),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
