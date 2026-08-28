import 'package:flutter/widgets.dart';

import 'game_icons.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// Where a modal sits over the screen it covers.
enum ModalAnchor {
  /// Over the middle. For a sheet the player opens to read.
  centre,

  /// Just above the tabs. For a menu reached for with a thumb, where the
  /// bottom of the screen is the shortest distance from the hand.
  bottom,

  /// Every pixel between the resource strip and the tabs. For a sheet with a
  /// list long enough to scroll, which would otherwise resize itself every
  /// time its contents changed.
  stretch,
}

/// The game's one modal: a scrim, a panel, and a titled bar with the way out.
///
/// Every sheet used to build its own -- its own scrim alpha, its own radius,
/// its own idea of where the close control goes. They are one widget now, so
/// a sheet added later is recognisably the same object as the console rather
/// than a second dialect of it. Only the contents differ.
class GameModal extends StatelessWidget {
  const GameModal({
    required this.title,
    required this.onClose,
    required this.child,
    this.icon,
    this.leading,
    this.accent = Palette.tech,
    this.anchor = ModalAnchor.centre,
    this.inset = 10,
    this.contentPadding = const EdgeInsets.fromLTRB(11, 4, 11, 13),
    this.trailing,
    this.footer,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  /// The glyph before the title. [icon] names one from the game's own set;
  /// [leading] is for a modal whose subject can draw itself -- an arm part
  /// shows the piece rather than a symbol standing in for it.
  final String? icon;
  final Widget? leading;

  /// The colour of the frame and of a named [icon]. A modal wears the colour
  /// of what it is about.
  final Color accent;

  final ModalAnchor anchor;

  /// Room left either side of the panel.
  final double inset;

  /// Room around the body. A modal whose body is a LIST hands the sides back
  /// to itself, so its separators can run the panel's full width instead of
  /// stopping short of it.
  final EdgeInsets contentPadding;

  /// A figure riding at the far end of the title bar, before the way out.
  /// For the one number that names the whole sheet -- the level a part
  /// stands at -- which belongs beside the title rather than under it.
  final Widget? trailing;

  /// A line under everything, held out of the scroll. For what is true of the
  /// whole sheet rather than of anything in it.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.bar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 26)],
      ),
      child: Column(
        // A stretched panel is given its height and fills it; the others take
        // whatever their contents ask for.
        mainAxisSize: anchor == ModalAnchor.stretch
            ? MainAxisSize.max
            : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 4),
            child: Row(
              children: [
                if (leading case final leading?) ...[
                  leading,
                  const SizedBox(width: 8),
                ] else if (icon case final icon?) ...[
                  GameIcon(icon, size: 16, colour: accent),
                  const SizedBox(width: 8),
                ],
                // The title and its figure travel together, and the slack
                // is left BETWEEN them and the way out. A Flexible title
                // beside a Spacer would split that slack instead, and the
                // close control would drift in from the edge.
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            11.5,
                            weight: FontWeight.w800,
                            color: Palette.text,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      if (trailing case final trailing?) ...[
                        const SizedBox(width: 10),
                        trailing,
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Ti.close, size: 15, color: Palette.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (anchor == ModalAnchor.stretch)
            Expanded(
              child: Padding(padding: contentPadding, child: child),
            )
          else
            Padding(padding: contentPadding, child: child),
          if (footer case final footer?) ...[
            const SizedBox(
              height: 1,
              child: ColoredBox(color: Palette.lineBar),
            ),
            footer,
          ],
        ],
      ),
    );

    return Stack(
      children: [
        // The scrim closes the modal too. A player who opened a sheet to look
        // at it should not have to find a control to stop looking.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0x99070A10)),
          ),
        ),
        switch (anchor) {
          ModalAnchor.bottom => Positioned(
            left: inset,
            right: inset,
            bottom: AppMetrics.navTotal + 8,
            child: panel,
          ),
          ModalAnchor.stretch => Positioned(
            top: AppMetrics.resourceBar - 8,
            left: inset,
            right: inset,
            bottom: AppMetrics.navTotal + 10,
            child: panel,
          ),
          ModalAnchor.centre => Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: panel,
              ),
            ),
          ),
        },
      ],
    );
  }
}
