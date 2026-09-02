import 'dart:async';

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
    this.holdRepeat = false,
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

  /// The auto-buy hold, the strike zone's own gesture on a button: the
  /// press fires once immediately, holding starts repeating after
  /// [holdDelayMs] (so a click can never buy twice), and the repeats wind
  /// up like held strikes do. For buttons that PURCHASE something.
  final bool holdRepeat;

  /// PROVISIONAL: the OS keyboard-repeat classic. A click is under
  /// 200 ms, so one click is always exactly one purchase.
  static const int holdDelayMs = 500;

  @override
  State<HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<HudButton> {
  bool _down = false;
  bool _hover = false;

  Timer? _repeat;
  static const int _startMs = 200;
  static const int _floorMs = 100;
  static const int _stepMs = 10;
  int _intervalMs = _startMs;

  void _setDown(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  void _holdDown() {
    _setDown(true);
    widget.onTap?.call();
    _intervalMs = _startMs;
    _repeat?.cancel();
    _repeat = Timer(
      const Duration(milliseconds: HudButton.holdDelayMs),
      _tickRepeat,
    );
  }

  void _tickRepeat() {
    // The wallet can run dry mid-hold: the rebuilt widget carries a null
    // onTap, and the hold ends by itself.
    if (widget.onTap == null) {
      _holdUp();
      return;
    }
    widget.onTap!();
    if (_intervalMs > _floorMs) {
      _intervalMs -= _stepMs;
      if (_intervalMs < _floorMs) _intervalMs = _floorMs;
    }
    _repeat = Timer(Duration(milliseconds: _intervalMs), _tickRepeat);
  }

  void _holdUp() {
    _repeat?.cancel();
    _repeat = null;
    _intervalMs = _startMs;
    _setDown(false);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
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
        // In hold-repeat mode the DOWN is the act (the strike zone's
        // language) and the up only ends the hold -- so a click buys once
        // and never double-fires through onTap.
        onTapDown: widget.holdRepeat
            ? (_) => _holdDown()
            : (_) => _setDown(true),
        onTapUp: widget.holdRepeat ? (_) => _holdUp() : (_) => _setDown(false),
        onTapCancel: widget.holdRepeat ? _holdUp : () => _setDown(false),
        onTap: widget.holdRepeat ? null : widget.onTap,
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
