import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'box.dart';
import 'corners.dart';
import 'tap.dart';

/// One choice among a few, drawn as ONE strip.
///
/// Every N-way pick in the game -- a share, a view, a room -- used to be a
/// row of separate chamfered slots, which is five little cards where the
/// player sees one control. Here the GROUP owns the outline: outer corners
/// are struck, inner seams are hairlines, and the lit cell is a fill inside
/// the shared shape rather than a box of its own.
class HudChoice<T> extends StatelessWidget {
  const HudChoice({
    required this.options,
    required this.value,
    required this.onPick,
    this.stretch = false,
    this.accent = Palette.gold,
    this.cut = 7,
    this.top = true,
    this.bottom = true,
    this.size = 9,
    this.padding = const EdgeInsets.fromLTRB(10, 5, 10, 6),
    this.marked = const {},
    super.key,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onPick;

  /// Share the row's width equally instead of hugging the labels. What a
  /// control seated across the screen wants; a picker in a heading does not.
  final bool stretch;

  final Color accent;
  final double cut;

  /// Which of the GROUP's corners are struck. A control seated on the floor
  /// of a screen keeps its top square -- the cut marks where the shape ends,
  /// and against an edge it does not end.
  final bool top;
  final bool bottom;

  final double size;
  final EdgeInsets padding;

  /// Options wearing the attention dot -- the same mark the navigation puts
  /// on a tab, so the player can follow it from the tab to the exact cell
  /// it is talking about.
  final Set<T> marked;

  @override
  Widget build(BuildContext context) {
    final corners = HudCorners(
      topLeft: top,
      topRight: top,
      bottomLeft: bottom,
      bottomRight: bottom,
    );
    final cells = <Widget>[];
    for (final (option, label) in options) {
      final active = option == value;
      final text = Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.body(
          size,
          weight: FontWeight.w700,
          letterSpacing: 1.2,
          color: active ? accent : Palette.textFaint,
        ),
      );
      Widget cell = HudTap(
        onTap: () => onPick(option),
        child: ColoredBox(
          color: active
              ? accent.withValues(alpha: 0.16)
              : const Color(0x00000000),
          child: Padding(
            padding: padding,
            // The dot rides IN the row beside the label, never hung off
            // its corner: a stretched cell's label spans the whole cell,
            // and a dot positioned past its edge left the strip entirely
            // and was eaten by the group's own clip.
            child: marked.contains(option)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: text),
                      const SizedBox(width: 5),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Palette.tech,
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.page, width: 1.5),
                        ),
                      ),
                    ],
                  )
                : text,
          ),
        ),
      );
      if (stretch) cell = Expanded(child: cell);
      if (cells.isNotEmpty) {
        cells.add(
          const SizedBox(width: 1, child: ColoredBox(color: Palette.lineBar)),
        );
      }
      cells.add(cell);
    }
    return HudBox(
      corners: corners,
      cut: cut,
      edge: Palette.lineBar,
      child: ClipPath(
        clipper: CornerClipper(corners, cut),
        // IntrinsicHeight so the hairline seams run the full height of the
        // strip instead of collapsing to the text's.
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
            children: cells,
          ),
        ),
      ),
    );
  }
}
