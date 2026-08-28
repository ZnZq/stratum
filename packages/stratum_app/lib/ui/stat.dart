import 'package:flutter/widgets.dart';

import 'game_icons.dart';
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
    this.label,
    this.value,
    this.child,
    this.size,
    this.colour = Palette.textDim,
    this.labelColour = Palette.tech,
    this.align = CrossAxisAlignment.start,
    this.note,
    this.icon,
    this.trailing,
    this.above,
    this.below,
    this.rule = false,
    this.shadows = false,
    super.key,
  }) : assert(
         value != null || child != null || label != null,
         'a readout needs a figure to show, or a name to be a heading',
       );

  /// The name over the figure. Absent on a bare reading -- a warehouse row
  /// whose name is already spelled out beside it -- and, with no figure, the
  /// whole widget: a section heading is a Stat that has nothing to report.
  final String? label;

  /// The figure itself. Pass [child] instead when it needs more than one
  /// style -- a gauge reading "700 / 700", or a number that animates.
  final String? value;
  final Widget? child;

  /// How big the figure is set. Defaults to the house size; a readout that
  /// has to share a crowded screen may ask for less without every other
  /// readout in the game shrinking with it.
  final double? size;

  final Color colour;

  /// The heading's own colour. Tech green is the house voice; a readout that
  /// belongs to one resource says so by wearing that resource's colour.
  final Color labelColour;

  final CrossAxisAlignment align;

  /// A quiet second line under the figure.
  final String? note;

  /// A glyph before the heading, in the heading's own colour. For a readout
  /// the player meets in several places at once -- depth in the mine and on
  /// the shell, say -- so the same idea keeps the same face wherever it turns
  /// up.
  final String? icon;

  /// A second fact riding beside the heading. For what belongs to the readout
  /// itself rather than to its figure -- the odds of a loot lane, say, which
  /// describe the lane and not the haul.
  final Widget? trailing;

  /// Free slots over the label and under everything, for a meter or a hint.
  final Widget? above;
  final Widget? below;

  /// A hairline running from the heading out to the far edge. For a heading
  /// that opens a SECTION rather than names a figure: the rule is what makes
  /// it read as a divider instead of as a stray word.
  final bool rule;

  /// Lifts the text off a busy background. The readouts standing over the
  /// strata need it; the ones on a panel do not.
  final bool shadows;

  static const double valueSize = 14;

  Widget? _heading() {
    final label = this.label;
    if (label == null) return null;
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
    if (icon == null && trailing == null && !rule) return text;

    final head = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon!, size: 11, colour: labelColour),
              const SizedBox(width: 5),
              Flexible(child: text),
            ],
          );

    if (rule) {
      // Centred, not baseline-aligned: the line is the heading's underscore
      // continued sideways, and it has no baseline of its own to sit on.
      return Row(
        children: [
          // NOT Flexible: a loose child and the Expanded rule would split the
          // free width between them, and the line would stop halfway to the
          // edge -- further short the longer the heading. A section name is
          // short by construction, so it takes its own width.
          head,
          if (trailing case final trailing?) ...[
            const SizedBox(width: 6),
            trailing,
          ],
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: labelColour.withValues(alpha: 0.15)),
            ),
          ),
        ],
      );
    }

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
          Flexible(child: head),
          const SizedBox(width: 6),
          trailing,
        ],
      );
    }
    return head;
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading();
    final figure =
        child ??
        (value == null
            ? null
            : Text(
                value!,
                style: AppText.display(
                  size ?? valueSize,
                  weight: FontWeight.w700,
                  color: colour,
                  shadows: shadows,
                ),
              ));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        if (above case final above?) ...[above, const SizedBox(height: 3)],
        if (heading != null) ...[heading, const SizedBox(height: 1)],
        ?figure,
        if (note case final note?)
          Text(note, style: AppText.display(9.5, color: Palette.textFaint)),
        if (below case final below?) ...[const SizedBox(height: 2), below],
      ],
    );
  }
}
