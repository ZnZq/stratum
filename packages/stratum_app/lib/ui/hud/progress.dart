import 'package:flutter/widgets.dart';

import '../tokens.dart';

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
    this.lead,
    this.leadColour,
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

  /// A second frontier AHEAD of [fraction], for a chasing bar: what just
  /// arrived is shown here instantly while the main fill animates up to it.
  final double? lead;

  /// The arrival's own colour -- "інший колір" is the whole point: the eye
  /// must see the new money as new before the fill swallows it.
  final Color? leadColour;

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
    // Width pinned to infinity on purpose: a bare CustomPaint sizes to the
    // SMALLEST loose constraint, and a bar dropped into a Stack quietly
    // became zero pixels wide. Infinity clamps to whatever room there is.
    Widget bar = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CellPainter(
          fraction: fraction.clamp(0.0, 1.0),
          accent: accent,
          from: from ?? Palette.amber,
          lead: (lead ?? 0).clamp(0.0, 1.0),
          leadTone: leadColour ?? accent.withValues(alpha: 0.4),
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
    this.lead = 0,
    this.leadTone = const Color(0x00000000),
  });

  final double fraction;
  final Color accent;
  final Color from;

  /// Cells past [fraction] up to here wear [leadTone]: the just-arrived
  /// stretch the fill has not caught up with yet.
  final double lead;
  final Color leadTone;

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

    // The arrival lane first, so the fill paints over the part it has
    // already claimed and only the fresh stretch shows through.
    if (lead > fraction) {
      final ahead = lead * count;
      for (var i = 0; i < count; i++) {
        final done = ahead - i;
        if (done <= 0) break;
        canvas.drawRect(
          Rect.fromLTWH(i * step, 0, cellW, h),
          Paint()..color = leadTone.withValues(alpha: done >= 1 ? 1.0 : 0.34),
        );
      }
    }

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
      old.fraction != fraction ||
      old.accent != accent ||
      old.from != from ||
      old.lead != lead ||
      old.leadTone != leadTone;
}
