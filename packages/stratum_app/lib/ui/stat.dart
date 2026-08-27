import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// One labelled readout, wherever the game shows a number.
///
/// Every panel used to grow its own: the deck had one, the head a near copy
/// with a different value size and its own extra slots, and the energy plate
/// spelled the same label style out by hand. They drifted a point of font
/// size at a time, so they are one widget now -- a readout added later picks
/// up the house style instead of inventing a third dialect of it.
class Stat extends StatelessWidget {
  const Stat({
    required this.label,
    this.value,
    this.child,
    this.colour = Palette.textDim,
    this.align = CrossAxisAlignment.start,
    this.note,
    this.above,
    this.below,
    this.shadows = false,
    super.key,
  }) : assert(
         value != null || child != null,
         'a readout needs a figure to show',
       );

  final String label;

  /// The figure itself. Pass [child] instead when it needs more than one
  /// style -- a gauge reading "700 / 700", or a number that animates.
  final String? value;
  final Widget? child;

  final Color colour;
  final CrossAxisAlignment align;

  /// A quiet second line under the figure.
  final String? note;

  /// Free slots over the label and under everything, for a meter or a hint.
  final Widget? above;
  final Widget? below;

  /// Lifts the text off a busy background. The readouts standing over the
  /// strata need it; the ones on a panel do not.
  final bool shadows;

  static const double valueSize = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        if (above case final above?) ...[above, const SizedBox(height: 3)],
        Text(
          label.toUpperCase(),
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
            shadows: shadows,
          ),
        ),
        const SizedBox(height: 1),
        child ??
            Text(
              value!,
              style: AppText.display(
                valueSize,
                weight: FontWeight.w700,
                color: colour,
                shadows: shadows,
              ),
            ),
        if (note case final note?)
          Text(note, style: AppText.display(9.5, color: Palette.textFaint)),
        if (below case final below?) ...[const SizedBox(height: 2), below],
      ],
    );
  }
}
