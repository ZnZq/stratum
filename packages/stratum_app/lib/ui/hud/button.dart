import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A control with two corners cut away.
///
/// The chamfer is the whole trick: a rounded rectangle reads as an app, a
/// clipped one reads as a panel switch. Nothing else about it departs from
/// the house -- same wells, same line colours, same uppercase label.
class HudButton extends StatefulWidget {
  const HudButton({
    required this.onTap,
    this.label,
    this.child,
    this.accent = Palette.gold,
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 9),
    this.width,
    super.key,
  }) : assert(label != null || child != null, 'a control needs a face');

  /// The simple case: one word, in the house's uppercase.
  final String? label;

  /// Anything else -- a price with its icon, a figure with a unit. Given
  /// instead of [label], and laid out by the caller, so swapping a control
  /// to this shape can never move what is inside it.
  final Widget? child;

  /// Room around the face. Defaulted, but every call site that had a size
  /// before keeps passing its own: a chamfer is a change of outline, and it
  /// must not become a change of layout.
  final EdgeInsets padding;

  /// Null leaves the control in its unavailable state, which is a real state
  /// and not a placeholder: a collapse with no full server cannot be taken.
  final VoidCallback? onTap;

  final Color accent;
  final double? width;

  @override
  State<HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<HudButton> {
  bool _down = false;
  bool _hover = false;

  void _setDown(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.onTap != null;
    final ink = live ? widget.accent : Palette.textFaint;
    final hot = live && _hover;
    return MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: CustomPaint(
            painter: _ChamferPainter(
              // Hover firms the same inks the button already wears -- the
              // shape must not change, or rows of buttons would shimmer.
              fill: live
                  ? widget.accent.withValues(alpha: hot ? 0.2 : 0.12)
                  : const Color(0x00000000),
              edge: live
                  ? widget.accent.withValues(alpha: hot ? 1.0 : 0.7)
                  : Palette.lineBar,
            ),
            child: SizedBox(
              width: widget.width,
              child: Padding(
                padding: widget.padding,
                child:
                    widget.child ??
                    Text(
                      widget.label!,
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        10,
                        weight: FontWeight.w800,
                        color: ink,
                        letterSpacing: 1.8,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChamferPainter extends CustomPainter {
  const _ChamferPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  static const double _cut = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = Path()
      ..moveTo(_cut, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - _cut)
      ..lineTo(w - _cut, h)
      ..lineTo(0, h)
      ..lineTo(0, _cut)
      ..close();
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(_ChamferPainter old) =>
      old.fill != fill || old.edge != edge;
}
