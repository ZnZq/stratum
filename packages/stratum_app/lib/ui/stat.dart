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
    this.labelColour = Palette.tech,
    this.align = CrossAxisAlignment.start,
    this.note,
    this.trailing,
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

  /// The heading's own colour. Tech green is the house voice; a readout that
  /// belongs to one resource says so by wearing that resource's colour.
  final Color labelColour;

  final CrossAxisAlignment align;

  /// A quiet second line under the figure.
  final String? note;

  /// A second fact riding beside the heading. For what belongs to the readout
  /// itself rather than to its figure -- the odds of a loot lane, say, which
  /// describe the lane and not the haul.
  final Widget? trailing;

  /// Free slots over the label and under everything, for a meter or a hint.
  final Widget? above;
  final Widget? below;

  /// Lifts the text off a busy background. The readouts standing over the
  /// strata need it; the ones on a panel do not.
  final bool shadows;

  static const double valueSize = 14;

  Widget _heading() {
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body(
        8.5,
        weight: FontWeight.w700,
        color: labelColour,
        letterSpacing: 1.6,
        shadows: shadows,
      ),
    );
    if (trailing case final trailing?) {
      // Expanded, not Flexible: a loose slot hands its slack back to the row
      // and the trailing fact ends up glued to the label instead of standing
      // at the far edge, where a second column of facts belongs.
      return Row(
        // Beside the heading, not at the far edge: the fact qualifies the
        // name, so it travels with it.
        mainAxisSize: MainAxisSize.min,
        // On the baseline, not the box: the heading is Manrope and a trailing
        // figure is usually Chakra Petch, and two fonts centred by line height
        // sit at visibly different levels.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: text),
          const SizedBox(width: 6),
          trailing,
        ],
      );
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        if (above case final above?) ...[above, const SizedBox(height: 3)],
        _heading(),
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
