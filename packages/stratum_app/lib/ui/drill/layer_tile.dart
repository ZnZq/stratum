import 'package:flutter/widgets.dart';

import '../gauge.dart';
import '../tokens.dart';

import 'package:stratum_core/stratum_core.dart';

import 'crack_painter.dart';
import 'stone_painter.dart';

class LayerTile extends StatelessWidget {
  const LayerTile({
    required this.layer,
    required this.isCurrent,
    required this.isPast,
    required this.hpFraction,
    super.key,
  });

  final int layer;
  final bool isCurrent;
  final bool isPast;
  final double hpFraction;

  @override
  Widget build(BuildContext context) {
    final thick = PrototypeSimulation.isThick(layer);
    final fill = thick ? Palette.thickLayer : Strata.fillFor(layer);
    final opacity = isPast ? 0.38 : (isCurrent ? 1.0 : 0.88);
    final damage = 1 - hpFraction;
    final labelled = (layer + 1) % 5 == 0;

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
          border: Border(
            top: BorderSide(
              color: thick ? Palette.gold : const Color(0x33A8C4E0),
              width: thick ? 2 : 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: StonePainter(layer: layer, thick: thick),
                ),
              ),
            ),
            if (isCurrent)
              Positioned.fill(
                child: CustomPaint(painter: CrackPainter(damage, layer: layer)),
              ),
            // The depth rail: a tick at every metre, a longer one with a
            // reading every fifth. An instrument scale rather than a caption
            // repeated on every layer.
            Positioned(
              left: 0,
              top: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: labelled ? 18 : 9,
                    height: 1,
                    color: labelled
                        ? const Color(0x997FD9C4)
                        : const Color(0x4D7FD9C4),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 6,
              child: Text(
                thick
                    ? '${layer + 1}–${layer + PrototypeSimulation.thickSpan} м'
                    : '${layer + 1} м',
                style: AppText.display(
                  10,
                  color: labelled ? Palette.tech : const Color(0x8CE8E9EE),
                  shadows: true,
                ),
              ),
            ),
            if (thick)
              Positioned(
                left: 12,
                top: 10,
                right: 12,
                child: Text(
                  'ТОВСТИЙ ШАР · всі ресурси '
                  '×${PrototypeSimulation.thickSpan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    11.5,
                    weight: FontWeight.w700,
                    color: Palette.gold,
                    shadows: true,
                  ),
                ),
              ),
            if (isCurrent)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: Gauge(
                  fraction: hpFraction,
                  height: 3,
                  radius: 0,
                  // No track: the rock behind it is already dark enough to
                  // read the fill against.
                  track: const Color(0x00000000),
                  gradient: const LinearGradient(
                    colors: [Palette.amber, Palette.gold],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
