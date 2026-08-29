import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Corner brackets instead of a frame.
///
/// The game's rule is one surface, no boxes inside boxes -- but a console
/// still needs to say where it begins. Four short Ls mark the corners and
/// leave the sides open, so the block is bracketed without being boxed.
class HudBrackets extends StatelessWidget {
  const HudBrackets({
    required this.child,
    this.colour = Palette.tech,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    super.key,
  });

  final Widget child;
  final Color colour;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BracketPainter(colour),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.colour);

  final Color colour;

  static const double _arm = 13;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = colour.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, _arm)
        ..lineTo(0, 0)
        ..lineTo(_arm, 0)
        ..moveTo(w - _arm, 0)
        ..lineTo(w, 0)
        ..lineTo(w, _arm)
        ..moveTo(w, h - _arm)
        ..lineTo(w, h)
        ..lineTo(w - _arm, h)
        ..moveTo(_arm, h)
        ..lineTo(0, h)
        ..lineTo(0, h - _arm),
      ink,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.colour != colour;
}

/// A control with two corners cut away.
///
/// The chamfer is the whole trick: a rounded rectangle reads as an app, a
/// clipped one reads as a panel switch. Nothing else about it departs from
/// the house -- same wells, same line colours, same uppercase label.
class HudButton extends StatefulWidget {
  const HudButton({
    required this.label,
    required this.onTap,
    this.accent = Palette.gold,
    this.width,
    super.key,
  });

  final String label;

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

  void _setDown(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.onTap != null;
    final ink = live ? widget.accent : Palette.textFaint;
    return GestureDetector(
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
            fill: live
                ? widget.accent.withValues(alpha: 0.12)
                : const Color(0x00000000),
            edge: live ? widget.accent.withValues(alpha: 0.7) : Palette.lineBar,
          ),
          child: SizedBox(
            width: widget.width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
              child: Text(
                widget.label,
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

/// The lamp that opens a console line: the same green/amber/red the server
/// racks run on, so one glance tells whether a thing is idle, working or
/// spent -- wherever it appears.
class HudLamp extends StatelessWidget {
  const HudLamp({required this.colour, this.size = 5, super.key});

  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colour.withValues(alpha: 0.5), blurRadius: 5),
        ],
      ),
    );
  }
}
