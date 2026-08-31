import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'craft_clock.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// One crafting line, laid out as the owner drew it: the compression panel
/// with its trade-offs on the left, the conveyor -- inputs in, machine,
/// product out -- in the middle, the effects strip under the belt, the two
/// line purchases at the bottom. The card's height never moves with its
/// state: a standing line keeps the same skeleton, dimmed.
class CraftLineCard extends StatefulWidget {
  const CraftLineCard({
    required this.game,
    required this.index,
    required this.onPickRecipe,
    required this.onChange,
    super.key,
  });

  final Game game;
  final int index;
  final VoidCallback onPickRecipe;
  final ValueChanged<VoidCallback> onChange;

  static const double height = 172;

  @override
  State<CraftLineCard> createState() => _CraftLineCardState();
}

class _CraftLineCardState extends State<CraftLineCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _last = Duration.zero;

  CraftLine get _line => widget.game.sim.craftLines[widget.index];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.value += clampFrameDelta(elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.game.sim;
    final line = _line;
    final recipe = craftRecipeOf(line.recipe.value);
    final style = recipe == null ? null : resourceStyles[recipe.output]!;
    final starving =
        recipe != null && !line.halted.value && line.starving.value;
    final working =
        recipe != null && !line.done && !line.halted.value && !starving;
    final edge = recipe == null
        ? Palette.lineBar
        : starving
        ? Palette.amber.withValues(alpha: 0.4)
        : style!.colour.withValues(alpha: 0.5);
    return SizedBox(
      height: CraftLineCard.height,
      child: HudBox(
        cut: 9,
        fill: Palette.shell.withValues(alpha: recipe == null ? 0.35 : 0.6),
        edge: edge,
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(line, recipe, style, working, starving),
            const SizedBox(height: 6),
            const HudRule(),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompressionPanel(
                    sim: sim,
                    index: widget.index,
                    onChange: widget.onChange,
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 1,
                    child: ColoredBox(color: Palette.lineBar),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ConveyorPainter(
                                    clock: _clock,
                                    running: working,
                                    speed:
                                        line.speedFactor.value *
                                        line.rampFactor,
                                    output: style?.colour,
                                    progressAt: line.craftProgress,
                                    clockAt: _clock.value,
                                    unitSeconds: line.effectiveSeconds,
                                  ),
                                ),
                              ),
                              if (working)
                                Positioned.fill(
                                  child: _ConveyorFreight(
                                    clock: _clock,
                                    clockAt: _clock.value,
                                    progressAt: line.craftProgress,
                                    unitSeconds: line.effectiveSeconds,
                                    inputs: [
                                      for (final id in recipe.inputs.keys)
                                        ResourceIcon(id, size: 13),
                                    ],
                                    product: ResourceIcon(
                                      recipe.output,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              if (recipe == null)
                                Center(
                                  child: HudButton(
                                    key: ValueKey(
                                      'craft.assign.${widget.index}',
                                    ),
                                    onTap: widget.onPickRecipe,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      6,
                                      16,
                                      7,
                                    ),
                                    label: 'ПРИЗНАЧИТИ РЕЦЕПТ',
                                  ),
                                ),
                              if (line.done)
                                Center(
                                  child: Text(
                                    'ВИКОНАНО · ${line.limit.value}',
                                    style: AppText.body(
                                      9,
                                      weight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: Palette.tech,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _EffectsStrip(line: line, live: recipe != null),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _LineBuy(
                    label: line.tierCap.value >= craftTierCapMax
                        ? 'КАП · СТЕЛЯ'
                        : 'КАП ×${1 << (line.tierCap.value + 1)}',
                    cost: line.tierCap.value >= craftTierCapMax
                        ? null
                        : sim.craftCapCost(widget.index),
                    enabled: sim.canBuyCraftCap(widget.index),
                    onTap: () =>
                        widget.onChange(() => sim.buyCraftCap(widget.index)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LineBuy(
                    label: 'ШВИДКІСТЬ +5%',
                    cost: sim.craftSpeedCost(widget.index),
                    enabled: sim.canBuyCraftSpeed(widget.index),
                    onTap: () =>
                        widget.onChange(() => sim.buyCraftSpeed(widget.index)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Craft rates start well under one unit a second, where the house
  /// number format rounds to a flat zero -- a floor reading of "+0 / с"
  /// would say the line is dead while the belt visibly runs.
  static String _rateText(BigDouble rate) {
    final v = rate.toDouble();
    // Three decimals under one: at high line speeds a +5% level moves the
    // third digit only, and a reading that cannot show it looks stuck.
    if (v < 1) return v.toStringAsFixed(3);
    return v < 10 ? v.toStringAsFixed(2) : '$rate';
  }

  Widget _header(
    CraftLine line,
    CraftRecipe? recipe,
    ResourceStyle? style,
    bool working,
    bool starving,
  ) {
    final lampColour = working
        ? Palette.tech
        : (starving && !line.halted.value)
        ? Palette.amber
        : Palette.line;
    return Row(
      children: [
        HudLamp(colour: lampColour),
        const SizedBox(width: 7),
        Text(
          'ЛІНІЯ ${widget.index + 1}',
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: Palette.textFaint,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(width: 8),
        if (recipe == null)
          Text('простоює', style: AppText.body(9, color: Palette.textFaint))
        else ...[
          // The recipe IS the tap target: retargeting the line is the
          // screen's most frequent act and costs one gesture.
          HudTap(
            onTap: widget.onPickRecipe,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResourceIcon(recipe.output, size: 14),
                const SizedBox(width: 5),
                Text(
                  style!.label.toUpperCase(),
                  style: AppText.body(
                    10,
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: style.colour,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Ti.chevronDown,
                  size: 10,
                  color: style.colour.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          _ModeBadge(line: line),
          const SizedBox(width: 7),
          Text(
            craftClock(line.effectiveSeconds),
            style: AppText.display(9, color: Palette.textFaint),
          ),
        ],
        const Spacer(),
        if (line.halted.value && recipe != null)
          Text('зупинено', style: AppText.body(8.5, color: Palette.textFaint))
        else if (starving)
          Text('голодує', style: AppText.body(8.5, color: Palette.amber))
        else if (recipe != null && !line.done)
          Text(
            '+${_rateText(line.ratePerSecond.value)} / с',
            style: AppText.display(
              12,
              weight: FontWeight.w700,
              color: Palette.tech,
            ),
          )
        else
          Text('— / с', style: AppText.display(9, color: Palette.textFaint)),
        if (recipe != null && !line.done) ...[
          const SizedBox(width: 8),
          _HaltButton(
            halted: line.halted.value,
            onTap: () => widget.onChange(
              () => widget.game.sim.setCraftHalted(
                widget.index,
                !line.halted.value,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Stop and resume by hand. A stopped machine keeps its recipe and its
/// order, frees the compression level, and loses its warm-up.
class _HaltButton extends StatelessWidget {
  const _HaltButton({required this.halted, required this.onTap});

  final bool halted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onTap,
      cut: 4,
      corners: HudCorners.centred,
      child: HudPlate(
        cut: 4,
        fill: halted ? Palette.goldWell : Palette.shell,
        edge: halted ? Palette.amber : Palette.line,
        child: SizedBox(
          width: 22,
          height: 18,
          child: Center(
            child: Icon(
              halted ? Ti.playerPlay : Ti.playerPause,
              size: 10,
              color: halted ? Palette.gold : Palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The run mode the recipe was launched with, worn as a status, never as a
/// control: the mode is chosen in the picker.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.line});

  final CraftLine line;

  @override
  Widget build(BuildContext context) {
    final endless = line.limit.value < 0;
    // A finite order counts DOWN -- 200, 197, 192 -- to the zero at which
    // the machine stands: what is left is the only figure the order needs.
    final left = (line.limit.value - line.producedCount.value).ceil();
    final text = endless ? '∞' : '${left < 0 ? 0 : left}';
    return HudPlate(
      cut: 4,
      fill: Palette.shell,
      edge: Palette.line,
      padding: const EdgeInsets.fromLTRB(6, 1, 6, 2),
      child: Text(
        text,
        style: AppText.display(
          8.5,
          weight: FontWeight.w700,
          color: Palette.gold,
        ),
      ),
    );
  }
}

/// The left panel: the chosen level against the bought ceiling, and what
/// the level trades. Locked while the line runs -- the lock is the message.
class _CompressionPanel extends StatelessWidget {
  const _CompressionPanel({
    required this.sim,
    required this.index,
    required this.onChange,
  });

  final PrototypeSimulation sim;
  final int index;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    final line = sim.craftLines[index];
    final locked = line.running;
    final tier = line.tier.value;
    final yieldMult = math.pow(craftYieldStep, tier).toDouble();
    final costMult = math.pow(craftCostStep, tier).toDouble();
    final timeMult = math.pow(craftTimeStep, tier).toDouble();
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'КОМПРЕСІЯ',
            style: AppText.body(
              7.5,
              weight: FontWeight.w700,
              color: Palette.textFaint,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (locked) ...[
                Icon(Ti.settings2, size: 10, color: Palette.textFaint),
                const SizedBox(width: 4),
                Text(
                  '$tier',
                  style: AppText.display(
                    14,
                    weight: FontWeight.w700,
                    color: Palette.text,
                  ),
                ),
              ] else ...[
                _Step(
                  glyph: '−',
                  enabled: tier > 0,
                  onTap: () =>
                      onChange(() => sim.setCraftTier(index, tier - 1)),
                ),
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      '$tier',
                      style: AppText.display(
                        14,
                        weight: FontWeight.w700,
                        color: Palette.text,
                      ),
                    ),
                  ),
                ),
                _Step(
                  glyph: '+',
                  enabled: tier < line.tierCap.value,
                  onTap: () =>
                      onChange(() => sim.setCraftTier(index, tier + 1)),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '/ ${line.tierCap.value}',
                style: AppText.display(9, color: Palette.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _mod('вихід', '×${_short(yieldMult)}', Palette.tech),
          _mod('витрата', '×${_short(costMult)}', Palette.amber),
          _mod('час', '×${_short(timeMult)}', Palette.amber),
          const Spacer(),
          Text(
            locked ? 'замкнено на час роботи' : 'вільно — лінія стоїть',
            style: AppText.body(6.8, color: Palette.textFaint),
          ),
        ],
      ),
    );
  }

  static String _short(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  Widget _mod(String name, String value, Color colour) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: Row(
      children: [
        Text(name, style: AppText.display(8, color: colour)),
        const Spacer(),
        Text(
          value,
          style: AppText.display(8, weight: FontWeight.w600, color: colour),
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.glyph,
    required this.enabled,
    required this.onTap,
  });

  final String glyph;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: enabled ? onTap : null,
      cut: 4,
      corners: HudCorners.centred,
      child: HudPlate(
        cut: 4,
        fill: Palette.shell,
        edge: enabled ? Palette.line : Palette.lineBar,
        child: SizedBox(
          width: 19,
          height: 18,
          child: Center(
            child: Text(
              glyph,
              style: AppText.display(
                11,
                weight: FontWeight.w700,
                color: enabled ? Palette.gold : Palette.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + value, nothing else (owner's rule): the final speed, the
/// duplicate chance, the warm-up.
class _EffectsStrip extends StatelessWidget {
  const _EffectsStrip({required this.line, required this.live});

  final CraftLine line;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final speed = line.speedFactor.value;
    return Opacity(
      opacity: live ? 1 : 0.45,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(
            _FxKind.speed,
            '×${speed.toStringAsFixed(2)}',
            live ? Palette.tech : Palette.textFaint,
          ),
          const SizedBox(width: 6),
          _chip(
            _FxKind.duplicate,
            '${(craftDuplicateChance * 100).round()}%',
            live ? Palette.gold : Palette.textFaint,
          ),
          const SizedBox(width: 6),
          _chip(
            _FxKind.ramp,
            '${(line.rampProgress * 100).round()}%',
            live ? Palette.steel : Palette.textFaint,
          ),
        ],
      ),
    );
  }

  Widget _chip(_FxKind kind, String value, Color colour) => HudPlate(
    cut: 4,
    fill: Palette.well.withValues(alpha: 0.7),
    edge: Palette.lineBar,
    padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(10, 10), painter: _FxGlyph(kind, colour)),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppText.display(9, weight: FontWeight.w700, color: colour),
        ),
      ],
    ),
  );
}

enum _FxKind { speed, duplicate, ramp }

/// The three effect glyphs -- a speedometer, a duplicate, a rising line --
/// drawn rather than fonted: the icon set has no matching trio.
class _FxGlyph extends CustomPainter {
  const _FxGlyph(this.kind, this.colour);

  final _FxKind kind;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = colour;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case _FxKind.speed:
        canvas.drawArc(
          Rect.fromLTWH(w * 0.08, h * 0.15, w * 0.84, h * 0.84),
          math.pi * 0.85,
          math.pi * 1.3,
          false,
          ink,
        );
        canvas.drawLine(
          Offset(w * 0.5, h * 0.6),
          Offset(w * 0.72, h * 0.3),
          ink,
        );
      case _FxKind.duplicate:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.12, h * 0.32, w * 0.55, h * 0.55),
          ink,
        );
        final back = Path()
          ..moveTo(w * 0.35, h * 0.32)
          ..lineTo(w * 0.35, h * 0.12)
          ..lineTo(w * 0.9, h * 0.12)
          ..lineTo(w * 0.9, h * 0.65)
          ..lineTo(w * 0.67, h * 0.65);
        canvas.drawPath(back, ink);
      case _FxKind.ramp:
        final line = Path()
          ..moveTo(w * 0.08, h * 0.85)
          ..lineTo(w * 0.42, h * 0.5)
          ..lineTo(w * 0.6, h * 0.68)
          ..lineTo(w * 0.92, h * 0.25);
        canvas.drawPath(line, ink);
        canvas.drawLine(
          Offset(w * 0.65, h * 0.25),
          Offset(w * 0.92, h * 0.25),
          ink,
        );
        canvas.drawLine(
          Offset(w * 0.92, h * 0.25),
          Offset(w * 0.92, h * 0.52),
          ink,
        );
    }
  }

  @override
  bool shouldRepaint(_FxGlyph old) => old.kind != kind || old.colour != colour;
}

/// A purchase of the line itself -- cap or speed -- with the price in the
/// preview, per safeguard five. Alive on an empty line too: the upgrades
/// belong to the machine, not to the recipe.
class _LineBuy extends StatelessWidget {
  const _LineBuy({
    required this.label,
    required this.cost,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final BigDouble? cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = enabled ? Palette.gold : Palette.textFaint;
    return HudButton(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.body(
                8,
                weight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colour,
              ),
            ),
            if (cost != null) ...[
              const SizedBox(width: 5),
              Text(
                '$cost',
                style: AppText.display(
                  9.5,
                  weight: FontWeight.w700,
                  color: colour,
                ),
              ),
              const SizedBox(width: 3),
              ResourceIcon(
                ResourceId.credits,
                size: 9,
                colour: enabled ? null : Palette.textFaint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The belt: inputs ride in from the left, the machine turns them over, the
/// product rides out to the right. Painted, not composed -- it generates its
/// shapes from the line's state, which is what painters are for here.
class _ConveyorPainter extends CustomPainter {
  _ConveyorPainter({
    required this.clock,
    required this.running,
    required this.speed,
    required this.output,
    required this.progressAt,
    required this.clockAt,
    required this.unitSeconds,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final bool running;

  /// The line's live pace (speed track x warm-up): a bought level must be
  /// visible on the belt itself, not only in a figure.
  final double speed;

  final Color? output;

  /// The current unit's progress as the core last settled it, and the
  /// clock instant it was read at: the drum extrapolates between syncs so
  /// the ring pours instead of stepping once a second.
  final double progressAt;
  final double clockAt;
  final double unitSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final t = running ? clock.value * speed : 0.0;
    final w = size.width;
    final beltY = size.height - 12;
    // The belt's top edge runs as a dashed line when the machine works.
    const dash = 10.0;
    const gap = 8.0;
    final offset = running ? (t * 26) % (dash + gap) : 0.0;
    // Starting one period LEFT and adding the offset makes the dashes run
    // rightward -- the same way the freight rides.
    var x = offset - (dash + gap);
    final beltInk = Paint()
      ..strokeWidth = 2
      ..color = Palette.line;
    while (x < w) {
      final from = x < 0 ? 0.0 : x;
      final to = math.min(x + dash, w);
      if (to > from) {
        canvas.drawLine(Offset(from, beltY), Offset(to, beltY), beltInk);
      }
      x += dash + gap;
    }
    canvas.drawLine(
      Offset(0, beltY + 8),
      Offset(w, beltY + 8),
      Paint()
        ..strokeWidth = 1
        ..color = Palette.lineBar,
    );
    for (var rx = 10.0; rx < w - 4; rx += 26) {
      canvas.drawCircle(
        Offset(rx, beltY + 4),
        2.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Palette.line,
      );
    }

    // The machine, centred over the belt -- kept LOW: the belt is the
    // scene, the housing is only the oven the batch disappears into.
    final mx = w / 2;
    final bodyTop = beltY - 42;
    final housing = Paint()..color = Palette.shell;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = running ? Palette.edge : Palette.line;
    final body = Rect.fromLTRB(mx - 24, bodyTop, mx + 24, beltY);
    canvas.drawRect(body, housing);
    canvas.drawRect(body, edge);
    final roof = Path()
      ..moveTo(mx - 24, bodyTop)
      ..lineTo(mx - 19, bodyTop - 6)
      ..lineTo(mx + 19, bodyTop - 6)
      ..lineTo(mx + 24, bodyTop)
      ..close();
    canvas.drawPath(roof, Paint()..color = Palette.well);
    canvas.drawPath(roof, edge);
    canvas.drawCircle(
      Offset(mx - 18, bodyTop + 6),
      2.4,
      Paint()..color = running ? Palette.tech : Palette.line,
    );

    // The drum is the unit's own clock: a ring that fills as the craft
    // nears, with the seconds left counted down in its middle.
    final drumC = Offset(mx, bodyTop + 17);
    canvas.drawCircle(drumC, 11, Paint()..color = const Color(0xFF10161F));
    canvas.drawCircle(
      drumC,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Palette.line,
    );
    if (output != null) {
      var progress = progressAt;
      if (running && unitSeconds > 0) {
        progress = (progressAt + (clock.value - clockAt) / unitSeconds) % 1.0;
      }
      canvas.drawArc(
        Rect.fromCircle(center: drumC, radius: 8.5),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.well,
      );
      canvas.drawArc(
        Rect.fromCircle(center: drumC, radius: 8.5),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = output!,
      );
      final left = (1 - progress) * unitSeconds;
      final label = TextPainter(
        text: TextSpan(
          text: _shortClock(left),
          style: AppText.display(
            6.5,
            weight: FontWeight.w700,
            color: Palette.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(drumC.dx - label.width / 2, drumC.dy + 13));
    }
  }

  /// The countdown squeezed into the drum: `43s`, `1:27`, `61m`.
  static String _shortClock(double seconds) {
    final whole = seconds.ceil();
    if (whole < 60) return '${whole}s';
    if (whole < 3600) {
      return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
    }
    return '${whole ~/ 60}m';
  }

  @override
  bool shouldRepaint(_ConveyorPainter old) =>
      old.running != running || old.speed != speed || old.output != output;
}

/// The freight on the belt, riding in CRAFT TIME: one journey is one
/// unit, and it NEVER stops. The batch -- every ingredient's icon --
/// rolls the whole belt in one motion; passing through the oven it
/// squeezes together and cross-fades into the product, which rides on
/// out at the same pace. The icons are handed in, not drawn.
class _ConveyorFreight extends StatelessWidget {
  const _ConveyorFreight({
    required this.clock,
    required this.clockAt,
    required this.progressAt,
    required this.unitSeconds,
    required this.inputs,
    required this.product,
  });

  final ValueNotifier<double> clock;
  final double clockAt;
  final double progressAt;
  final double unitSeconds;
  final List<Widget> inputs;
  final Widget product;

  /// Where along the ride the transformation happens -- exactly while the
  /// freight crosses the oven, which sits at the midpoint.
  static const double _morphFrom = 0.40;
  static const double _morphTo = 0.60;
  static const double _spacing = 15;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final beltY = constraints.maxHeight - 12;
        return AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            var p = progressAt;
            if (unitSeconds > 0) {
              p = (progressAt + (clock.value - clockAt) / unitSeconds) % 1.0;
            }
            // One straight run, off-screen to off-screen; the oven sits at
            // the midpoint, so the cross-fade lands right on its window.
            final cx = -24 + (w + 48) * p;
            final morph = p <= _morphFrom
                ? 0.0
                : p >= _morphTo
                ? 1.0
                : (p - _morphFrom) / (_morphTo - _morphFrom);
            final entry = p < 0.05 ? p / 0.05 : 1.0;
            final exit = p > 0.95 ? (1 - p) / 0.05 : 1.0;
            final gap = _spacing * (1 - morph);
            final batchFade = ((1 - morph) * entry).clamp(0.0, 1.0);
            final productFade = (morph * exit).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (batchFade > 0)
                  for (var i = 0; i < inputs.length; i++)
                    Positioned(
                      left: cx + (i - (inputs.length - 1) / 2) * gap - 6.5,
                      top: beltY - 15,
                      child: Opacity(opacity: batchFade, child: inputs[i]),
                    ),
                if (productFade > 0)
                  Positioned(
                    left: cx - 7,
                    top: beltY - 16,
                    child: Opacity(opacity: productFade, child: product),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
