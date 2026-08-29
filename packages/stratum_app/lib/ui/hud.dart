import 'package:flutter/widgets.dart';

import 'game_icons.dart';
// For ModalAnchor, which both sheets share. If the chamfered panel
// wins, the anchor moves here and game_modal.dart goes.
import 'game_modal.dart';
import 'stat.dart';
import 'tabler_icons.dart';
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

/// A bar built out of cells, in a chamfered track.
///
/// The house already has one bar -- [Gauge] -- and it is the right one for a
/// reading that pours: energy sweeping, a layer wearing down. This is the
/// other kind: a track the player is CROSSING, where what matters is how many
/// steps are behind and how many are left. Cells say that; a smooth fill does
/// not.
///
/// The cell being filled now is drawn faint rather than full, the same way a
/// server rack marks the slot it is working on, so the frontier is visible
/// without a second colour.
class HudProgress extends StatelessWidget {
  const HudProgress({
    required this.fraction,
    this.height = 13,
    this.accent = Palette.gold,
    this.reading,
    super.key,
  });

  final double fraction;
  final double height;
  final Color accent;

  /// The figure written across the track.
  ///
  /// Styled here rather than by the caller, and set on a plate of its own: a
  /// reading laid straight onto the cells has to be legible over amber on one
  /// side and over the empty track on the other, and no single ink colour
  /// does both. The plate settles it once for every bar.
  final String? reading;

  @override
  Widget build(BuildContext context) {
    final bar = CustomPaint(
      painter: _CellPainter(fraction: fraction.clamp(0.0, 1.0), accent: accent),
    );
    if (reading == null) return SizedBox(height: height, child: bar);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          bar,
          Center(
            child: Container(
              // Horizontal room only: at 13 tall the track has about two
              // pixels of outline top and bottom, and a plate with vertical
              // padding covers exactly those.
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: const Color(0xD90E141C),
              // Nudged down by the gap between the text BOX and the text INK.
              // The reading is digits and a slash, none of which descend, so
              // the font's descent sits empty at the bottom of the box and
              // centring the box leaves the glyphs riding high. Line height
              // is pinned to 1 first, so this is the whole remaining error.
              child: Transform.translate(
                offset: const Offset(0, 0.8),
                child: Text(
                  reading!,
                  style: AppText.display(
                    8.5,
                    weight: FontWeight.w700,
                    color: Palette.text,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  /// About how wide one cell wants to be. The count is derived from the room
  /// available rather than fixed, so the same bar reads the same whether it
  /// spans a card or a panel.
  static const double _cell = 9;
  static const double _gap = 2;
  static const double _cut = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final track = Path()
      ..moveTo(_cut, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - _cut)
      ..lineTo(w - _cut, h)
      ..lineTo(0, h)
      ..lineTo(0, _cut)
      ..close();

    canvas.drawPath(track, Paint()..color = Palette.shell);

    final count = (w / _cell).round().clamp(6, 48);
    // Gaps BETWEEN the cells only: the run has to start on the track's left
    // edge and finish on its right, or the bar reads as inset from its own
    // frame. So the width is shared out after the gaps are taken out, rather
    // than each cell being trimmed on both sides.
    final cellW = (w - _gap * (count - 1)) / count;
    final step = cellW + _gap;
    final filled = fraction * count;

    canvas.save();
    canvas.clipPath(track);
    for (var i = 0; i < count; i++) {
      final ahead = i - filled;
      if (ahead >= 1) break;
      // Full behind the frontier, faint at it: the cell being worked on
      // reads as in progress rather than as done.
      final alpha = ahead <= 0 ? 1.0 : 0.34;
      canvas.drawRect(
        Rect.fromLTWH(i * step, 0, cellW, h),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Palette.amber.withValues(alpha: alpha),
              accent.withValues(alpha: alpha),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.restore();

    canvas.drawPath(
      track,
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.fraction != fraction || old.accent != accent;
}

/// A navigation cell: the button's chamfer with its top and bottom opened.
///
/// A menu is a run of slots, not a row of separate controls. Closing every
/// cell on all four sides drew four boxes; leaving the horizontal edges open
/// turns the same outline into two angled brackets per slot, and the row
/// reads as one strip of a panel with the selected slot lit.
class HudMenu extends StatelessWidget {
  const HudMenu({
    required this.child,
    required this.onTap,
    this.active = false,
    this.accent = Palette.gold,
    this.cut = 8,
    this.padding = const EdgeInsets.symmetric(vertical: 5),
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool active;
  final Color accent;

  /// How much of each corner is taken off. Smaller cells want a smaller cut,
  /// or the chamfer eats the slot.
  final double cut;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _MenuPainter(active: active, accent: accent, cut: cut),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _MenuPainter extends CustomPainter {
  const _MenuPainter({
    required this.active,
    required this.accent,
    required this.cut,
  });

  final bool active;
  final Color accent;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cut = this.cut > h / 2 ? h / 2 : this.cut;

    // All four corners taken off, not the button's two: a menu cell is a
    // slot in a strip and reads as one when both ends are cut the same way,
    // where the button's diagonal pair reads as a direction.
    canvas.drawPath(
      Path()
        ..moveTo(cut, 0)
        ..lineTo(w - cut, 0)
        ..lineTo(w, cut)
        ..lineTo(w, h - cut)
        ..lineTo(w - cut, h)
        ..lineTo(cut, h)
        ..lineTo(0, h - cut)
        ..lineTo(0, cut)
        ..close(),
      Paint()
        ..color = active
            ? accent.withValues(alpha: 0.14)
            : const Color(0x00000000),
    );

    // Two symmetric brackets: the horizontals stay open, so the row reads
    // as one strip rather than a line of boxes.
    canvas.drawPath(
      Path()
        ..moveTo(cut, 0)
        ..lineTo(0, cut)
        ..lineTo(0, h - cut)
        ..lineTo(cut, h)
        ..moveTo(w - cut, 0)
        ..lineTo(w, cut)
        ..lineTo(w, h - cut)
        ..lineTo(w - cut, h),
      Paint()
        ..color = active ? accent.withValues(alpha: 0.85) : Palette.lineBar
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.4 : 1
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_MenuPainter old) =>
      old.active != active || old.accent != accent || old.cut != cut;
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
    final panel = CustomPaint(
      painter: _PanelPainter(accent),
      child: Column(
        mainAxisSize: anchor == ModalAnchor.stretch
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
          SizedBox(
            height: 1,
            child: ColoredBox(color: accent.withValues(alpha: 0.2)),
          ),
          if (anchor == ModalAnchor.stretch)
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

class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.accent);

  final Color accent;

  static const double _cut = 15;
  static const double _bracket = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = Path()
      ..moveTo(_cut, 0)
      ..lineTo(w - _cut, 0)
      ..lineTo(w, _cut)
      ..lineTo(w, h - _cut)
      ..lineTo(w - _cut, h)
      ..lineTo(_cut, h)
      ..lineTo(0, h - _cut)
      ..lineTo(0, _cut)
      ..close();

    canvas.drawPath(
      shape,
      Paint()
        ..color = Palette.bar
        ..maskFilter = null,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // The corners struck harder than the sides: the eye takes the shape from
    // them, which is what lets the rest of the outline stay this quiet.
    final ink = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square;
    canvas.drawPath(
      Path()
        ..moveTo(_bracket, 0)
        ..lineTo(_cut, 0)
        ..lineTo(0, _cut)
        ..lineTo(0, _bracket)
        ..moveTo(w - _bracket, 0)
        ..lineTo(w - _cut, 0)
        ..lineTo(w, _cut)
        ..lineTo(w, _bracket)
        ..moveTo(w, h - _bracket)
        ..lineTo(w, h - _cut)
        ..lineTo(w - _cut, h)
        ..lineTo(w - _bracket, h)
        ..moveTo(_bracket, h)
        ..lineTo(_cut, h)
        ..lineTo(0, h - _cut)
        ..lineTo(0, h - _bracket),
      ink,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) => old.accent != accent;
}

/// Which corners a chamfer takes off.
///
/// A set rather than a preset, because a run of plates has to be able to read
/// as ONE cut panel: the block's outer corners are struck and its inner ones
/// are left square, which no per-plate rule can work out on its own.
///
/// The presets cover the common case -- the cut follows the reading, so a
/// figure read from the left is struck where the eye enters and where it
/// leaves, and one read from the right has that pair mirrored.
class HudCorners {
  const HudCorners({
    this.topLeft = false,
    this.topRight = false,
    this.bottomRight = false,
    this.bottomLeft = false,
  });

  final bool topLeft;
  final bool topRight;
  final bool bottomRight;
  final bool bottomLeft;

  static const HudCorners none = HudCorners();
  static const HudCorners leading = HudCorners(
    topLeft: true,
    bottomRight: true,
  );
  static const HudCorners trailing = HudCorners(
    topRight: true,
    bottomLeft: true,
  );
  static const HudCorners centred = HudCorners(
    topLeft: true,
    topRight: true,
    bottomRight: true,
    bottomLeft: true,
  );

  static HudCorners of(CrossAxisAlignment align) => switch (align) {
    CrossAxisAlignment.end => trailing,
    CrossAxisAlignment.center => centred,
    _ => leading,
  };

  Path path(Size size, double cut) {
    final w = size.width;
    final h = size.height;
    final c = cut > h / 2 ? h / 2 : cut;
    final path = Path()..moveTo(topLeft ? c : 0, 0);
    if (topRight) {
      path
        ..lineTo(w - c, 0)
        ..lineTo(w, c);
    } else {
      path.lineTo(w, 0);
    }
    if (bottomRight) {
      path
        ..lineTo(w, h - c)
        ..lineTo(w - c, h);
    } else {
      path.lineTo(w, h);
    }
    if (bottomLeft) {
      path
        ..lineTo(c, h)
        ..lineTo(0, h - c);
    } else {
      path.lineTo(0, h);
    }
    if (topLeft) path.lineTo(0, c);
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is HudCorners &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}

/// A chamfered surface with nothing to press.
///
/// The panel equivalent of a rounded Container: a fill, an optional edge, and
/// corners taken off to whatever pattern the content asks for.
class HudPlate extends StatelessWidget {
  const HudPlate({
    required this.child,
    this.corners = HudCorners.centred,
    this.fill,
    this.edge,
    this.cut = 7,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final HudCorners corners;
  final Color? fill;
  final Color? edge;
  final double cut;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlatePainter(
        corners: corners,
        fill: fill,
        edge: edge,
        cut: cut,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({
    required this.corners,
    required this.fill,
    required this.edge,
    required this.cut,
  });

  final HudCorners corners;
  final Color? fill;
  final Color? edge;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = corners.path(size, cut);
    if (fill case final fill?) canvas.drawPath(shape, Paint()..color = fill);
    if (edge case final edge?) {
      canvas.drawPath(
        shape,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.corners != corners ||
      old.fill != fill ||
      old.edge != edge ||
      old.cut != cut;
}

/// A readout on a plate of its own, cut to the way it is read.
///
/// The house [Stat] does the type; this only frames it. So a HUD readout can
/// never drift from a plain one -- same heading size, same figure weight, same
/// unit slot -- and what it adds is the surface, not a second dialect.
class HudStat extends StatelessWidget {
  const HudStat({
    required this.label,
    this.value,
    this.child,
    this.align = CrossAxisAlignment.start,
    this.corners,
    this.accent = Palette.tech,
    this.colour = Palette.textDim,
    this.labelColour = Palette.tech,
    this.size,
    this.unit,
    // Tight at the sides on purpose: a plate that costs eleven pixels either
    // side takes them out of the heading, and the heading is the part that
    // cannot be abbreviated.
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 9),
    this.cut = 9,
    super.key,
  });

  final String label;
  final String? value;
  final Widget? child;
  final CrossAxisAlignment align;

  /// Overrides the cut the alignment would choose. For a grid of plates that
  /// has to read as one panel: only the block's outer corners are struck.
  final HudCorners? corners;

  /// The colour of the plate's edge.
  final Color accent;

  final Color colour;
  final Color labelColour;
  final double? size;
  final Widget? unit;
  final EdgeInsets padding;
  final double cut;

  @override
  Widget build(BuildContext context) {
    return HudPlate(
      corners: corners ?? HudCorners.of(align),
      cut: cut,
      fill: accent.withValues(alpha: 0.05),
      edge: accent.withValues(alpha: 0.28),
      padding: padding,
      child: Stat(
        label: label,
        value: value,
        align: align,
        colour: colour,
        labelColour: labelColour,
        size: size,
        unit: unit,
        child: child,
      ),
    );
  }
}
