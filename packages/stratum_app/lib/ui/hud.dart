import 'package:flutter/widgets.dart';

import 'game_icons.dart';
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
    this.struck = HudCorners.centred,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    super.key,
  });

  final Widget child;
  final Color colour;

  /// Which corners are marked. Four is a console; the bottom pair alone is a
  /// plinth the block is seated on, which is what a block INSIDE a framed
  /// screen wants -- four would be a second frame around the first.
  final HudCorners struck;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      corners: HudCorners.none,
      sides: HudSides.none,
      bracket: colour.withValues(alpha: 0.34),
      brackets: struck,
      bracketWidth: 1.2,
      bracketArm: 13,
      padding: padding,
      child: child,
    );
  }
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
/// Where a bar's figure is written.
enum HudReading {
  /// Over the track, beside the label. Costs a line and owes the fill
  /// nothing, which is what a bar with room above it should take.
  above,

  /// Across the cells. For a bar packed into a card or a strip where there
  /// is no line to spare -- it is lifted off the fill by a shadow rather
  /// than by a plate, because a plate is a hole punched in the very cells
  /// the bar is drawing.
  inside,
}

class HudProgress extends StatelessWidget {
  const HudProgress({
    required this.fraction,
    this.height = 13,
    this.accent = Palette.gold,
    this.from,
    this.label,
    this.reading,
    this.readingColour,
    this.place = HudReading.above,
    super.key,
  });

  final double fraction;
  final double height;

  /// The colour the fill runs TO, and the colour of the track's outline.
  final Color accent;

  /// The colour the fill runs FROM. Null keeps the house warm start, which is
  /// what a track being walked wants; a cold bar passes its own so the run
  /// does not begin in amber.
  final Color? from;

  /// What the bar measures, written at its head. Without it a bar is a
  /// quantity with no noun: the player can see that something is 3% along and
  /// not what. Always above the track, wherever the figure goes.
  final String? label;

  /// The figure. [place] decides whether it rides over the track or across
  /// it.
  final String? reading;

  /// The figure's ink. Null takes the accent above the track and the house
  /// text colour inside it -- inside, the figure crosses both the fill and
  /// the empty run, and only a near-white reads over both.
  final Color? readingColour;

  final HudReading place;

  @override
  Widget build(BuildContext context) {
    final inside = place == HudReading.inside && reading != null;
    Widget bar = SizedBox(
      height: height,
      child: CustomPaint(
        painter: _CellPainter(
          fraction: fraction.clamp(0.0, 1.0),
          accent: accent,
          from: from ?? Palette.amber,
        ),
      ),
    );

    if (inside) {
      bar = SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            bar,
            Align(
              // At the tail of the track, not across its middle: the middle
              // is where the frontier usually is, so a centred figure spent
              // most of its life sitting on the one cell the eye is looking
              // for.
              alignment: Alignment.centerRight,
              // Nudged down by the gap between the text BOX and the text INK:
              // a figure of digits and a slash has nothing that descends, so
              // the font's descent sits empty at the foot of the box and
              // centring the box alone leaves the glyphs riding high. Line
              // height is pinned to 1 first, so this is the whole remaining
              // error.
              child: Transform.translate(
                offset: const Offset(-7, 0.8),
                child: Text(
                  reading!,
                  // A halo, not the house lift: the lift falls 2 px down
                  // and to nothing sideways, and that much weight under an
                  // 8.5 px figure reads as the figure sitting high even when
                  // the metrics put it dead centre.
                  style: AppText.display(
                    8.5,
                    weight: FontWeight.w700,
                    color: readingColour ?? Palette.text,
                    height: 1,
                  ).copyWith(shadows: AppText.halo),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (label == null && (reading == null || inside)) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (label case final label?)
              Text(
                label,
                style: AppText.body(
                  8,
                  weight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.75),
                  letterSpacing: 2,
                ),
              ),
            const Spacer(),
            if (reading case final reading? when !inside)
              Text(
                reading,
                style: AppText.display(
                  10.5,
                  weight: FontWeight.w700,
                  color: readingColour ?? accent,
                  height: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        bar,
      ],
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter({
    required this.fraction,
    required this.accent,
    required this.from,
  });

  final double fraction;
  final Color accent;
  final Color from;

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
      // How much of THIS cell is filled, 0 to 1. Measured from the cell's
      // start rather than its index: comparing the index to the frontier
      // counted cell zero as done at zero progress, so an empty track showed
      // one lit segment.
      final done = filled - i;
      if (done <= 0) break;
      // Full behind the frontier, faint at it: the cell being worked on
      // reads as in progress rather than as done.
      final alpha = done >= 1 ? 1.0 : 0.34;
      canvas.drawRect(
        Rect.fromLTWH(i * step, 0, cellW, h),
        Paint()
          ..shader = LinearGradient(
            colors: [
              from.withValues(alpha: alpha),
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
      old.fraction != fraction || old.accent != accent || old.from != from;
}

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
      Widget cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(option),
        child: ColoredBox(
          color: active
              ? accent.withValues(alpha: 0.16)
              : const Color(0x00000000),
          child: Padding(
            padding: padding,
            child: marked.contains(option)
                ? Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.passthrough,
                    children: [
                      text,
                      Positioned(
                        top: -1,
                        right: -6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Palette.tech,
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.page, width: 1.5),
                          ),
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
        clipper: _CornerClipper(corners, cut),
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
      child: HudBox(
        corners: HudCorners.centred,
        // Horizontals open: the run reads as one strip of a panel rather
        // than a line of separate boxes.
        sides: HudSides.upright,
        cut: cut,
        fill: active ? accent.withValues(alpha: 0.14) : null,
        edge: active ? accent.withValues(alpha: 0.85) : Palette.lineBar,
        edgeWidth: active ? 1.4 : 1,
        padding: padding,
        child: child,
      ),
    );
  }
}

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

/// Which straight runs of the outline are drawn.
///
/// Separate from the corners because they are separate decisions: a menu cell
/// is cut on all four and drawn on two, and a bracket frame is cut on none
/// and drawn on none at all.
class HudSides {
  const HudSides({
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.left = true,
  });

  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  static const HudSides all = HudSides();
  static const HudSides none = HudSides(
    top: false,
    right: false,
    bottom: false,
    left: false,
  );

  /// Left and right only: the run reads as one strip rather than a line of
  /// boxes, which is what a menu wants.
  static const HudSides upright = HudSides(top: false, bottom: false);
}

/// The one surface every HUD part is cut from.
///
/// Corners, sides and corner strikes are three independent choices, and every
/// panel in the game turns out to be a combination of them: a plate is all
/// sides and no strikes, a menu cell is two sides, a bracket frame is no
/// sides and long strikes, a sheet is every side with short ones. Holding
/// them apart is what stopped this file from growing a painter per shape.
class HudBox extends StatelessWidget {
  const HudBox({
    required this.child,
    this.corners = HudCorners.centred,
    this.sides = HudSides.all,
    this.cut = 8,
    this.fill,
    this.edge,
    this.edgeWidth = 1,
    this.bracket,
    this.bracketWidth = 1.6,
    this.bracketArm = 0,
    this.brackets = HudCorners.centred,
    this.padding = EdgeInsets.zero,
    this.over = false,
    super.key,
  });

  final Widget child;
  final HudCorners corners;
  final HudSides sides;
  final double cut;

  /// The body. Null leaves whatever is behind showing through.
  final Color? fill;

  /// The thin outline, drawn along the enabled [sides] and across every cut.
  final Color? edge;
  final double edgeWidth;

  /// The heavy strike at each corner, drawn over the edge. The eye takes a
  /// shape from its corners, which is what lets the rest of an outline stay
  /// quiet -- or disappear entirely.
  final Color? bracket;
  final double bracketWidth;

  /// How far a strike runs along each side it meets. Zero marks the cut
  /// alone; a long arm makes the corner brackets of a frame.
  final double bracketArm;

  /// WHICH corners are struck. A fourth axis, held apart from [corners] for
  /// the same reason the first three are: which corners are cut and which are
  /// hit are different questions, and a shape that can only answer them
  /// together cannot be a plinth, a header rule or an open bracket.
  final HudCorners brackets;

  final EdgeInsets padding;

  /// Draws the outline OVER the child instead of behind it. For a box whose
  /// content fills it to the edge -- a screen, a clipped panel -- where an
  /// outline underneath is simply covered up.
  final bool over;

  @override
  Widget build(BuildContext context) {
    final painter = _BoxPainter(
      corners: corners,
      sides: sides,
      cut: cut,
      fill: fill,
      edge: edge,
      edgeWidth: edgeWidth,
      bracket: bracket,
      bracketWidth: bracketWidth,
      bracketArm: bracketArm,
      brackets: brackets,
    );
    return CustomPaint(
      painter: over ? null : painter,
      foregroundPainter: over ? painter : null,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter({
    required this.corners,
    required this.sides,
    required this.cut,
    required this.fill,
    required this.edge,
    required this.edgeWidth,
    required this.bracket,
    required this.bracketWidth,
    required this.bracketArm,
    required this.brackets,
  });

  final HudCorners corners;
  final HudSides sides;
  final double cut;
  final Color? fill;
  final Color? edge;
  final double edgeWidth;
  final Color? bracket;
  final double bracketWidth;
  final double bracketArm;
  final HudCorners brackets;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = cut > h / 2 ? h / 2 : cut;

    if (fill case final fill?) {
      canvas.drawPath(corners.path(size, cut), Paint()..color = fill);
    }

    if (edge case final edge?) {
      final ink = Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..strokeCap = StrokeCap.square;
      final line = Path();
      if (sides.top) {
        line
          ..moveTo(corners.topLeft ? c : 0, 0)
          ..lineTo(corners.topRight ? w - c : w, 0);
      }
      if (sides.right) {
        line
          ..moveTo(w, corners.topRight ? c : 0)
          ..lineTo(w, corners.bottomRight ? h - c : h);
      }
      if (sides.bottom) {
        line
          ..moveTo(corners.bottomRight ? w - c : w, h)
          ..lineTo(corners.bottomLeft ? c : 0, h);
      }
      if (sides.left) {
        line
          ..moveTo(0, corners.bottomLeft ? h - c : h)
          ..lineTo(0, corners.topLeft ? c : 0);
      }
      // A cut belongs to the outline whenever either side it joins is drawn:
      // otherwise a menu cell would show two floating verticals.
      if (corners.topLeft && (sides.top || sides.left)) {
        line
          ..moveTo(c, 0)
          ..lineTo(0, c);
      }
      if (corners.topRight && (sides.top || sides.right)) {
        line
          ..moveTo(w - c, 0)
          ..lineTo(w, c);
      }
      if (corners.bottomRight && (sides.bottom || sides.right)) {
        line
          ..moveTo(w, h - c)
          ..lineTo(w - c, h);
      }
      if (corners.bottomLeft && (sides.bottom || sides.left)) {
        line
          ..moveTo(c, h)
          ..lineTo(0, h - c);
      }
      canvas.drawPath(line, ink);
    }

    if (bracket case final bracket?) {
      final arm = bracketArm;
      final ink = Paint()
        ..color = bracket
        ..style = PaintingStyle.stroke
        ..strokeWidth = bracketWidth
        ..strokeCap = StrokeCap.square;
      final strike = Path();

      void corner(
        bool struck,
        bool isCut,
        Offset alongTop,
        Offset cutStart,
        Offset cutEnd,
        Offset alongSide,
        Offset square,
      ) {
        if (!struck) return;
        if (isCut) {
          strike
            ..moveTo(alongTop.dx, alongTop.dy)
            ..lineTo(cutStart.dx, cutStart.dy)
            ..lineTo(cutEnd.dx, cutEnd.dy)
            ..lineTo(alongSide.dx, alongSide.dy);
        } else {
          strike
            ..moveTo(alongTop.dx, alongTop.dy)
            ..lineTo(square.dx, square.dy)
            ..lineTo(alongSide.dx, alongSide.dy);
        }
      }

      corner(
        brackets.topLeft,
        corners.topLeft,
        Offset(c + arm, 0),
        Offset(c, 0),
        Offset(0, c),
        Offset(0, c + arm),
        Offset.zero,
      );
      corner(
        brackets.topRight,
        corners.topRight,
        Offset(w - c - arm, 0),
        Offset(w - c, 0),
        Offset(w, c),
        Offset(w, c + arm),
        Offset(w, 0),
      );
      corner(
        brackets.bottomRight,
        corners.bottomRight,
        Offset(w - c - arm, h),
        Offset(w - c, h),
        Offset(w, h - c),
        Offset(w, h - c - arm),
        Offset(w, h),
      );
      corner(
        brackets.bottomLeft,
        corners.bottomLeft,
        Offset(c + arm, h),
        Offset(c, h),
        Offset(0, h - c),
        Offset(0, h - c - arm),
        Offset(0, h),
      );
      canvas.drawPath(strike, ink);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.corners != corners ||
      old.sides.top != sides.top ||
      old.sides.right != sides.right ||
      old.sides.bottom != sides.bottom ||
      old.sides.left != sides.left ||
      old.cut != cut ||
      old.fill != fill ||
      old.edge != edge ||
      old.bracket != bracket ||
      old.bracketArm != bracketArm ||
      old.brackets != brackets;
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
    return HudBox(
      corners: corners,
      cut: cut,
      fill: fill,
      edge: edge,
      padding: padding,
      child: child,
    );
  }
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

/// The frame a whole screen lives in.
///
/// The island every screen sat on was a rounded card with a shadow, which is
/// the one place the app still looked like an app. Same job -- clip the screen
/// and mark its edge -- with the console's outline: corners cut, a quiet edge,
/// and the four corners struck.
///
/// The screen is clipped to the chamfer, so a full-bleed scene (the borehole,
/// the arm's rock band) stops on the cut instead of running past it, and the
/// outline is painted OVER the content, because an opaque screen fills the
/// clip right to its edge.
class HudScreen extends StatelessWidget {
  const HudScreen({
    required this.child,
    this.cut = 18,
    this.edge = Palette.line,
    this.accent = Palette.tech,
    super.key,
  });

  final Widget child;
  final double cut;

  /// The quiet run along each side.
  final Color edge;

  /// The corners, in a colour of their own. Struck in the same grey as the
  /// sides they simply read as a slightly thicker line; the point of a
  /// bracket is that the eye finds the shape from it, and it cannot do that
  /// while the bracket is the same thing as the edge.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      corners: HudCorners.centred,
      cut: cut,
      edge: edge,
      bracket: accent.withValues(alpha: 0.7),
      bracketWidth: 1.8,
      bracketArm: 16,
      over: true,
      child: ClipPath(
        clipper: _CornerClipper(HudCorners.centred, cut),
        child: child,
      ),
    );
  }
}

/// Clips to the same outline a [HudBox] draws, so content and frame agree.
class _CornerClipper extends CustomClipper<Path> {
  const _CornerClipper(this.corners, this.cut);

  final HudCorners corners;
  final double cut;

  @override
  Path getClip(Size size) => corners.path(size, cut);

  @override
  bool shouldReclip(_CornerClipper old) =>
      old.corners != corners || old.cut != cut;
}

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
