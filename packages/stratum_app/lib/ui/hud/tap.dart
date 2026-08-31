import 'package:flutter/widgets.dart';

import 'corners.dart';

/// The house tap surface.
///
/// One widget owns what "pressable" means on a desktop: the click cursor,
/// and a faint wash while the pointer rests on it. Every plain tap target
/// goes through here so the mouse story cannot drift control by control;
/// the stateful controls (buttons, mine face) speak the same language with
/// their own hands.
class HudTap extends StatefulWidget {
  const HudTap({
    required this.child,
    required this.onTap,
    this.wash = true,
    this.corners,
    this.cut = 8,
    super.key,
  });

  final Widget child;

  /// Null renders the child inert: default cursor, no wash, no hit target.
  final VoidCallback? onTap;

  /// The hover wash. Off for targets that carry their own hover story.
  final bool wash;

  /// The child's outline, when it has one. A wash is a rectangle by
  /// default, and a rectangle over a chamfered slot paints the very corners
  /// the outline cut away -- the wrapper cannot know the shape, so shaped
  /// targets say theirs.
  final HudCorners? corners;
  final double cut;

  @override
  State<HudTap> createState() => _HudTapState();
}

class _HudTapState extends State<HudTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.onTap != null;
    Widget body = widget.child;
    if (live && widget.wash && _hover) {
      Widget film = const ColoredBox(color: Color(0x0DFFFFFF));
      if (widget.corners case final corners?) {
        film = ClipPath(
          clipper: CornerClipper(corners, widget.cut),
          child: film,
        );
      }
      body = Stack(
        fit: StackFit.passthrough,
        children: [
          body,
          Positioned.fill(child: IgnorePointer(child: film)),
        ],
      );
    }
    return MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      // The one raw GestureDetector this file is allowed: HudTap is where
      // the pattern bottoms out, and the sweep that routes every plain tap
      // through HudTap once rewrote this line into HudTap itself -- a
      // widget building itself, and a stack overflow on the first frame.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}
