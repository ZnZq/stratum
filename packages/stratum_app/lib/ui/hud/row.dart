import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A line of a list, marked by a rule down its left edge and washed with the
/// accent behind it.
///
/// Costs NO height: the wash and the rule are decoration -- painted behind
/// the row and along its edge -- so a dense list keeps the height it had.
/// Only the side insets are new, and insets on the side are free vertically.
/// That is the whole reason this shape works where a framed card would not.
class HudRow extends StatelessWidget {
  const HudRow({
    required this.child,
    this.accent = Palette.amber,
    this.rule = 2,
    this.padding = const EdgeInsets.only(left: 5, right: 6),
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final Widget child;

  /// The rule and, at a fraction of its opacity, the wash.
  final Color accent;

  final double rule;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(color: accent, width: rule),
        ),
      ),
      child: child,
    );
  }
}
