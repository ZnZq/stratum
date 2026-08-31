import 'package:flutter/widgets.dart';

import '../game_icons.dart';

import '../tabler_icons.dart';
import '../tokens.dart';
import 'box.dart';
import 'corners.dart';
import 'lamp.dart';
import 'tap.dart';

/// Where a sheet sits over the screen it covers.
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

  /// Fills the AREA THE MODAL IS MOUNTED IN, edge to edge. For sheets that
  /// live inside a screen's own stack: [stretch] subtracts the shell's
  /// chrome, which such a stack has already subtracted once.
  fill,
}

/// A panel cut out of the console, rather than a card laid on top of it.
///
/// Same anatomy as the modal the game already uses -- scrim, titled bar, a
/// way out, an optional footer -- but the outline is chamfered instead of
/// rounded and the corners are struck with brackets, so a sheet reads as part
/// of the same instrument as the buttons and the menu strip.
class HudModal extends StatelessWidget {
  const HudModal({
    required this.title,
    required this.onClose,
    required this.child,
    this.icon,
    this.leading,
    this.trailing,
    this.footer,
    this.accent = Palette.tech,
    this.anchor = ModalAnchor.centre,
    this.inset = 10,
    this.contentPadding = const EdgeInsets.fromLTRB(13, 6, 13, 14),
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final String? icon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;
  final Color accent;
  final ModalAnchor anchor;
  final double inset;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final panel = HudBox(
      corners: HudCorners.centred,
      cut: 15,
      fill: Palette.bar,
      edge: accent.withValues(alpha: 0.28),
      bracket: accent.withValues(alpha: 0.85),
      bracketArm: 7,
      child: Column(
        mainAxisSize:
            anchor == ModalAnchor.stretch || anchor == ModalAnchor.fill
            ? MainAxisSize.max
            : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 10, 9),
            child: Row(
              children: [
                HudLamp(colour: accent),
                const SizedBox(width: 9),
                if (leading case final leading?) ...[
                  leading,
                  const SizedBox(width: 8),
                ] else if (icon case final icon?) ...[
                  GameIcon(icon, size: 15, colour: accent),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      11,
                      weight: FontWeight.w800,
                      color: Palette.text,
                      letterSpacing: 2.6,
                    ),
                  ),
                ),
                if (trailing case final trailing?) ...[
                  trailing,
                  const SizedBox(width: 6),
                ],
                HudTap(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Ti.close, size: 15, color: Palette.textMuted),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 1,
            child: ColoredBox(color: accent.withValues(alpha: 0.2)),
          ),
          if (anchor == ModalAnchor.stretch || anchor == ModalAnchor.fill)
            Expanded(
              child: Padding(padding: contentPadding, child: child),
            )
          else
            Padding(padding: contentPadding, child: child),
          if (footer case final footer?) ...[
            SizedBox(
              height: 1,
              child: ColoredBox(color: accent.withValues(alpha: 0.2)),
            ),
            footer,
          ],
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          // A raw detector on purpose: the scrim closes on a click, but its
          // affordance is the cross in the header -- a hand cursor and a
          // hover film across half the screen would claim the BACKDROP is
          // the control.
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
          ModalAnchor.fill => Positioned(
            top: 4,
            left: inset,
            right: inset,
            bottom: 6,
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
