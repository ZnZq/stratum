import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'clock_text.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';
import 'phase_servo.dart';
import 'tier_track.dart';

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

  /// The unit phase every conveyor layer reads. Advanced by the ticker and
  /// SERVO-LOCKED to the core's own progress: the core settles once a
  /// second in a lump, and painters that extrapolated from a build-time
  /// snapshot visibly snapped every time the lump landed -- at one-second
  /// crafts the snap even crossed the wrap and flashed phantom crates.
  /// A single phase nudged toward the truth cannot jump by construction.
  final ValueNotifier<double> _phase = ValueNotifier(0);
  Duration _last = Duration.zero;

  /// The job the scene was last drawn for: a recipe change or an ordinal
  /// rolling back (re-assign, compression change) is a NEW job, and the
  /// scene lands on it instantly instead of chasing.
  ResourceId? _recipeSeen;
  int _ordinalSeen = 0;

  /// The scene's own smooth phase, settling to the core in a third of a
  /// second -- the pace the conveyor was tuned to.
  final PhaseServo _servo = PhaseServo(settleSeconds: 1 / 3);

  CraftLine get _line => widget.game.sim.craftLines[widget.index];

  @override
  void initState() {
    super.initState();
    _servo.snap(_line.craftProgress);
    _phase.value = _servo.phase;
    _recipeSeen = _line.recipe.value;
    _ordinalSeen = _line.unitOrdinal.value;
    _ticker = createTicker((elapsed) {
      final raw = elapsed - _last;
      final dt = clampFrameDelta(raw).inMicroseconds / 1e6;
      _last = elapsed;
      _clock.value += dt;
      final lines = widget.game.sim.craftLines;
      if (widget.index >= lines.length) return;
      final line = lines[widget.index];
      final unit = line.effectiveSeconds;
      final ordinal = line.unitOrdinal.value;
      // A fresh job is a snap, never a chase; so is a line that is not
      // running. Frame holes are the servo's own business.
      final newJob = line.recipe.value != _recipeSeen || ordinal < _ordinalSeen;
      _recipeSeen = line.recipe.value;
      _ordinalSeen = ordinal;
      if (newJob || !line.running || line.starving.value || unit <= 0) {
        _servo.snap(line.craftProgress);
      } else {
        _servo.advance(
          dt: dt,
          raw: raw.inMicroseconds / 1e6,
          unitSeconds: unit,
          core: line.craftProgress,
        );
      }
      _phase.value = _servo.phase;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _phase.dispose();
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
    final laden = recipe != null && !line.done;
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
            const SizedBox(height: 7),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompressionPanel(sim: sim, index: widget.index),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ConveyorPainter(
                                clock: _clock,
                                running: working,
                                speed: line.speedFactor.value,
                                dialFrac: recipe == null
                                    ? 0
                                    : (1 -
                                              line.craftSeconds.value /
                                                  (recipe.baseSeconds *
                                                      craftTimeScaleAt(
                                                        line.tier.value,
                                                      )))
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                                floored:
                                    recipe != null &&
                                    line.craftSeconds.value <=
                                        craftMinSeconds + 1e-9,
                                boost: line.boostStacks.value,
                                rate: recipe == null
                                    ? null
                                    : working
                                    ? '+${_rateText(line.ratePerSecond.value)} / с'
                                    : '—',
                                dups: line.dupCount.value,
                                lastDup: _dupNow(line),
                                output: style?.colour,
                                phase: _phase,
                                unitSeconds: line.effectiveSeconds,
                                crateW: recipe == null ? 24 : _crateW(recipe),
                                hasPrev: _hasPrev(line),
                                laden: laden,
                              ),
                            ),
                          ),
                          if (laden)
                            Positioned.fill(
                              child: _ConveyorFreight(
                                clock: _clock,
                                phase: _phase,
                                unitSeconds: line.effectiveSeconds,
                                crateW: _crateW(recipe),
                                hasPrev: _hasPrev(line),
                                doubled: _dupNow(line),
                                frozen: !working,
                                inputs: [
                                  for (final id in recipe.inputs.keys)
                                    ResourceIcon(id, size: 13),
                                ],
                                product: ResourceIcon(recipe.output, size: 14),
                              ),
                            ),
                          if (laden)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ConveyorFront(
                                  clock: _clock,
                                  phase: _phase,
                                  unitSeconds: line.effectiveSeconds,
                                  output: style!.colour,
                                  crateW: _crateW(recipe),
                                  hasPrev: _hasPrev(line),
                                  doubled: _dupNow(line),
                                ),
                              ),
                            ),
                          if (recipe == null)
                            Center(
                              child: HudButton(
                                key: ValueKey('craft.assign.${widget.index}'),
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

  static double _crateW(CraftRecipe recipe) =>
      (recipe.inputs.length - 1) * 13.0 + 24;

  /// Whether a finished unit exists to ride out at the start of this one.
  static bool _hasPrev(CraftLine line) =>
      line.producedCount.value >= line.unitsPerCraft.value - 1e-9;

  /// Whether the crate riding out carries a DOUBLE yield: the duplicate
  /// roll of the unit that just finished, quoted from the core -- the
  /// crate shows exactly what the stock was paid.
  static bool _dupNow(CraftLine line) {
    final n = line.unitOrdinal.value;
    return n > 0 && craftDuplicateRoll(n - 1);
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
    // A fixed height: the cancel button (18) is the header's tallest
    // guest, and an empty line must not settle lower when it leaves --
    // the static-height rule the card itself already obeys.
    return SizedBox(
      height: 18,
      child: Row(
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
            Text(
              craftClock(line.effectiveSeconds),
              style: AppText.display(9, color: Palette.textFaint),
            ),
          ],
          const Spacer(),
          // The rate lives in the scene now, with the other instruments;
          // the header keeps only the states a lamp cannot tell.
          if (line.halted.value && recipe != null)
            Text('зупинено', style: AppText.body(8.5, color: Palette.textFaint))
          else if (starving)
            Text('голодує', style: AppText.body(8.5, color: Palette.amber)),
          if (recipe != null) ...[
            const SizedBox(width: 8),
            _CancelButton(
              onTap: () => widget.onChange(
                () => widget.game.sim.assignCraftRecipe(widget.index, null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cancels the order outright: the line goes back to standing empty.
/// A pause had no gameplay purpose -- what a player actually wants is to
/// free the machine for something else, and that is one tap plus a fresh
/// launch from the picker.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onTap,
      cut: 4,
      corners: HudCorners.centred,
      child: HudPlate(
        cut: 4,
        fill: Palette.shell,
        edge: Palette.line,
        child: SizedBox(
          width: 22,
          height: 18,
          child: Center(
            child: Icon(Ti.close, size: 10, color: Palette.textMuted),
          ),
        ),
      ),
    );
  }
}

/// The line's instrument board -- a READOUT, never a control: the level
/// and everything else are set in the recipe picker, and pausing does not
/// make the board editable. Cells for the ladder (a level is something one
/// CROSSES), the trade the level makes, and the runway.
class _CompressionPanel extends StatelessWidget {
  const _CompressionPanel({required this.sim, required this.index});

  final PrototypeSimulation sim;
  final int index;

  @override
  Widget build(BuildContext context) {
    final line = sim.craftLines[index];
    final tier = line.tier.value;
    final cap = line.tierCap.value;
    final yieldMult = math.pow(craftYieldStep, tier).toDouble();
    final costMult = craftCostScaleAt(tier);
    final timeMult = craftTimeScaleAt(tier);
    final runway = line.recipe.value == null ? -1.0 : line.runwaySeconds.value;
    return SizedBox(
      width: 114,
      child: HudPlate(
        cut: 5,
        fill: Palette.well.withValues(alpha: 0.55),
        edge: Palette.lineBar,
        padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'КОМПРЕСІЯ',
                  style: AppText.body(
                    7,
                    weight: FontWeight.w700,
                    color: Palette.textFaint,
                    letterSpacing: 1.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '$tier',
                  style: AppText.display(
                    12,
                    weight: FontWeight.w700,
                    color: Palette.text,
                  ),
                ),
                Text(
                  ' / $cap',
                  style: AppText.display(8.5, color: Palette.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // The track: chosen cells lit, bought ones banked, the rest of
            // the ladder dark -- one glance says level, ceiling, headroom.
            TierTrack(tier: tier, cap: cap),
            const SizedBox(height: 5),
            _mod('вихід', '×${_short(yieldMult)}', Palette.tech),
            _mod('витрата', '×${_short(costMult)}', Palette.amber),
            _mod('час', '×${_short(timeMult)}', Palette.amber),
            const Spacer(),
            const HudRule(),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  'режим',
                  style: AppText.body(
                    7,
                    weight: FontWeight.w700,
                    color: Palette.textFaint,
                    letterSpacing: 1.3,
                  ),
                ),
                const Spacer(),
                Text(
                  _modeText(line),
                  style: AppText.display(
                    9,
                    weight: FontWeight.w700,
                    color: line.recipe.value == null
                        ? Palette.textFaint
                        : Palette.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                Text(
                  'запас',
                  style: AppText.body(
                    7,
                    weight: FontWeight.w700,
                    color: Palette.textFaint,
                    letterSpacing: 1.3,
                  ),
                ),
                const Spacer(),
                Text(
                  runway < 0
                      ? '—'
                      : runway > 24 * 3600
                      ? '>24h'
                      : craftClock(runway),
                  style: AppText.display(
                    9,
                    weight: FontWeight.w700,
                    color: runway < 0
                        ? Palette.textFaint
                        : runway < 60
                        ? Palette.amber
                        : Palette.textDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  /// The run mode as the board quotes it: endless, or the COUNTDOWN of
  /// what the finite order still owes (the mode-badge language).
  static String _modeText(CraftLine line) {
    if (line.recipe.value == null) return '—';
    if (line.limit.value < 0) return '∞';
    final left = (line.limit.value - line.producedCount.value).ceil();
    return '${left < 0 ? 0 : left}';
  }

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
      holdRepeat: true,
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
    required this.phase,
    required this.running,
    required this.speed,
    required this.dialFrac,
    required this.floored,
    required this.boost,
    required this.rate,
    required this.dups,
    required this.lastDup,
    required this.output,
    required this.unitSeconds,
    required this.crateW,
    required this.hasPrev,
    required this.laden,
  }) : super(repaint: Listenable.merge([clock, phase]));

  final ValueNotifier<double> clock;
  final bool running;

  /// The line's live pace, boost included: a bought level must be visible
  /// on the belt itself, not only in a figure. The dial quotes the same
  /// number -- one truth for the eye and the maths.
  final double speed;

  /// The dial's needle: how much faster the craft runs than its OWN
  /// starting pace (the recipe's time at this tier, no upgrades), 0..1.
  final double dialFrac;

  /// The craft sits on the one-second floor: the line is at its maximum,
  /// and the needle lives on the redline, trembling.
  final bool floored;

  /// The warm-up pile for the equalizer, in whole stacks.
  final int boost;

  /// The line's live output rate, composed by the card ('+0.15 / с'),
  /// hung over the ENTRY lane; null on an empty line, an em dash while
  /// the line stands. The header no longer quotes it.
  final String? rate;

  /// The duplicate counter over the exit lane, and whether the unit that
  /// JUST finished won the roll -- the golden beat quotes the core.
  final int dups;
  final bool lastDup;

  final Color? output;

  /// The card's servo-locked unit phase; every layer reads the same one.
  final ValueNotifier<double> phase;
  final double unitSeconds;
  final double crateW;
  final bool hasPrev;

  /// An assigned, unfinished line keeps its crates on the belt even while
  /// paused -- the freeze-frame rule.
  final bool laden;

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
    // Rollers with a visible spin: the belt must read as a machine even
    // while a long craft's freight is crawling.
    final spokeInk = Paint()
      ..strokeWidth = 1.1
      ..color = Palette.line;
    for (var rx = 10.0; rx < w - 4; rx += 26) {
      final c = Offset(rx, beltY + 4);
      canvas.drawCircle(
        c,
        2.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Palette.line,
      );
      final a = t * 3.4 + rx * 0.5;
      canvas.drawLine(
        c,
        c + Offset(math.cos(a) * 2.2, math.sin(a) * 2.2),
        spokeInk,
      );
    }

    // The machine, centred over the belt. Tall enough that the press
    // below the window has an honest travel to stamp with.
    final mx = w / 2;
    final bodyTop = beltY - 50;
    final housing = Paint()..color = Palette.shell;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = running ? Palette.edge : Palette.line;
    // The housing wraps AROUND the belt: its skirt drops past the band,
    // so the conveyor visibly runs INTO the machine, not under a box
    // standing on it.
    final body = Rect.fromLTRB(mx - 24, bodyTop, mx + 24, beltY + 8);
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

    // The belt runs on THROUGH the housing: a floor and its pit inside,
    // so an empty oven still has somewhere for a crate to stand.
    canvas.drawRect(
      Rect.fromLTRB(mx - 22, beltY + 1, mx + 22, beltY + 7),
      Paint()..color = const Color(0xFF10161F),
    );
    canvas.drawLine(
      Offset(mx - 22, beltY),
      Offset(mx + 22, beltY),
      Paint()
        ..strokeWidth = 2
        ..color = Palette.line,
    );

    // The instruments live IN the scene. Left, a dial with a needle for
    // the line's live pace; right, an equalizer of boost stacks -- whole
    // cells for a whole-stack mechanic; over the exit lane, the x2 tag.
    void glowText(
      String text,
      Offset at,
      Color colour,
      double size, {
      bool centred = false,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: AppText.display(size, weight: FontWeight.w700, color: colour),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, centred ? at - Offset(tp.width / 2, 0) : at);
    }

    final dimmed = output == null;

    // --- the speed dial. The needle maps 1x..infinity onto the sweep as
    // 1 - 1/v, so every bought level moves it and it never pins.
    final dialC = const Offset(15, 13);
    const dialR = 10.0;
    const sweepStart = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    canvas.drawCircle(dialC, dialR, Paint()..color = const Color(0xFF10161F));
    canvas.drawCircle(
      dialC,
      dialR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.lineBar,
    );
    for (var i = 0; i <= 4; i++) {
      final a = sweepStart + sweep * i / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        dialC + dir * (dialR - 1),
        dialC + dir * (dialR - 3.5),
        Paint()
          ..strokeWidth = 1
          ..color = Palette.line,
      );
    }
    // The redline: the last stretch of the sweep, where only the floor
    // can put the needle.
    const redStart = 0.86;
    canvas.drawArc(
      Rect.fromCircle(center: dialC, radius: dialR - 2),
      sweepStart + sweep * redStart,
      sweep * (1 - redStart),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.alarm.withValues(alpha: dimmed ? 0.2 : 0.45),
    );
    double needleF;
    final tj = clock.value;
    if (floored && !dimmed) {
      // Pinned on the redline, trembling like an engine at the limiter.
      needleF =
          0.93 +
          (running ? 0.035 * math.sin(tj * 11) + 0.02 * math.sin(tj * 29) : 0);
    } else {
      // A quiet idle wobble at any pace: a live machine never holds a
      // needle perfectly still. Gentler and slower than the redline's.
      final wobble = running && !dimmed
          ? 0.010 * math.sin(tj * 2.7) + 0.006 * math.sin(tj * 6.1)
          : 0.0;
      needleF = (dialFrac * redStart + wobble).clamp(0.0, redStart);
    }
    if (!dimmed && needleF > 0.004) {
      // The lit arc trails the needle, so the dial reads at a glance.
      canvas.drawArc(
        Rect.fromCircle(center: dialC, radius: dialR - 2),
        sweepStart,
        sweep * needleF,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.tech.withValues(alpha: 0.45),
      );
    }
    final na = sweepStart + sweep * needleF;
    final needleInk = dimmed
        ? Palette.textFaint
        : floored
        ? Palette.alarm
        : Palette.gold;
    canvas.drawLine(
      dialC,
      dialC + Offset(math.cos(na), math.sin(na)) * (dialR - 2.5),
      Paint()
        ..strokeWidth = 1.4
        ..color = needleInk,
    );
    canvas.drawCircle(dialC, 1.6, Paint()..color = needleInk);
    glowText(
      '×${speed.toStringAsFixed(2)}',
      const Offset(29, 3),
      dimmed ? Palette.textFaint : Palette.tech,
      8,
    );
    glowText('ШВИДКІСТЬ', const Offset(29, 14), Palette.textFaint, 5);

    // --- the boost equalizer: one rising cell per stack, gold at the cap.
    const cells = craftBoostCap;
    const cellW = 3.0;
    const cellGap = 1.6;
    final eqRight = w - 5;
    final eqLeft = eqRight - cells * cellW - (cells - 1) * cellGap;
    final atCap = boost >= cells;
    final fillInk = Paint()
      ..color = dimmed
          ? Palette.textFaint
          : (atCap ? Palette.gold : Palette.steel);
    final emptyInk = Paint()..color = Palette.card;
    for (var i = 0; i < cells; i++) {
      final cx0 = eqLeft + i * (cellW + cellGap);
      final ch = 4.5 + i * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(cx0, 21 - ch, cellW, ch),
        i < boost ? fillInk : emptyInk,
      );
    }
    canvas.drawLine(
      Offset(eqLeft, 22),
      Offset(eqRight, 22),
      Paint()
        ..strokeWidth = 1
        ..color = fillInk.color.withValues(alpha: dimmed ? 0.35 : 0.55),
    );
    glowText('РОЗГІН', Offset(eqLeft, 3), Palette.textFaint, 5);
    glowText(
      '$boost/$cells',
      Offset(eqRight - 22, 2.4),
      dimmed ? Palette.textFaint : (atCap ? Palette.gold : Palette.steel),
      6.5,
    );

    // --- the rate over the ENTRY lane, mirroring the duplicate counter:
    // what the machine turns the incoming freight into, per second.
    final rateX = (4 + mx - 24) / 2;
    glowText(
      'ТЕМП',
      Offset(rateX, beltY - 47),
      Palette.textFaint,
      5,
      centred: true,
    );
    glowText(
      rate ?? '—',
      Offset(rateX, beltY - 40),
      dimmed || rate == null || rate == '—' ? Palette.textFaint : Palette.tech,
      7,
      centred: true,
    );

    // --- the duplicate counter over the exit lane: the odds on top, the
    // job's winnings under them, and the doubled crates ride right below.
    final dupX = (mx + 24 + w - 4) / 2;
    glowText(
      'ДУБЛІ ${(craftDuplicateChance * 100).round()}%',
      Offset(dupX, beltY - 47),
      Palette.textFaint,
      5,
      centred: true,
    );
    glowText(
      '$dups',
      Offset(dupX, beltY - 40),
      dimmed ? Palette.textFaint : Palette.gold,
      8,
      centred: true,
    );

    // The window sits high: the unit's clock, ring and countdown in one.
    final drumC = Offset(mx, bodyTop + 13);
    canvas.drawCircle(drumC, 10, Paint()..color = const Color(0xFF10161F));
    canvas.drawCircle(
      drumC,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Palette.line,
    );
    if (output != null) {
      final progress = phase.value;
      // The oven glows with every stamp of the press.
      if (running && _BeltStory.pressing(progress, unitSeconds)) {
        final ext = _BeltStory.piston(
          _BeltStory.pressSeconds(progress, unitSeconds),
        );
        canvas.drawCircle(
          drumC,
          14,
          Paint()
            ..color = output!.withValues(alpha: 0.08 + 0.16 * ext)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      // The beat of completion: the filled ring rolls outward and dies.
      // A unit that won the duplicate roll finishes GOLD, and louder --
      // a second ring and a glow, the oven's little jackpot.
      if (running && progress < 0.07) {
        final wk = progress / 0.07;
        final beat = lastDup ? Palette.gold : output!;
        canvas.drawCircle(
          drumC,
          10 + wk * (lastDup ? 12 : 8),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * (1 - wk)
            ..color = beat.withValues(alpha: 0.6 * (1 - wk)),
        );
        if (lastDup) {
          canvas.drawCircle(
            drumC,
            6 + wk * 14,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1 * (1 - wk)
              ..color = Palette.gold.withValues(alpha: 0.4 * (1 - wk)),
          );
          canvas.drawCircle(
            drumC,
            13,
            Paint()
              ..color = Palette.gold.withValues(alpha: 0.22 * (1 - wk))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
          );
        }
      }
      canvas.drawArc(
        Rect.fromCircle(center: drumC, radius: 7.5),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.well,
      );
      canvas.drawArc(
        Rect.fromCircle(center: drumC, radius: 7.5),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = output!,
      );
      if (laden) {
        // Every crate on the belt gets its interior painted behind the
        // freight icons; the front walls ride in the layer above them.
        for (final cx in _BeltStory.crates(
          progress,
          w,
          crateW,
          unitSeconds,
          hasPrev: hasPrev,
        )) {
          canvas.drawRect(
            Rect.fromLTWH(cx - crateW / 2, beltY - 13, crateW, 12),
            Paint()..color = const Color(0xFF10161F),
          );
        }
      }
      final left = (1 - progress) * unitSeconds;
      final label = TextPainter(
        text: TextSpan(
          text: shortClock(left),
          style: AppText.display(
            6,
            weight: FontWeight.w700,
            color: Palette.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, drumC - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ConveyorPainter old) =>
      old.running != running ||
      old.speed != speed ||
      old.dialFrac != dialFrac ||
      old.floored != floored ||
      old.boost != boost ||
      old.rate != rate ||
      old.dups != dups ||
      old.lastDup != lastDup ||
      old.output != output;
}

/// The pipeline choreography, shared by all three conveyor layers.
///
/// The rides never cost craft time. The press works a unit from the
/// moment its crate parks to the moment it wraps; meanwhile the NEXT
/// crate stages at the mouth during the tail of the current unit, and the
/// FINISHED crate rides out during the head of the next one. Logistics
/// overlap the neighbouring units instead of eating this one.
abstract final class _BeltStory {
  static const double rideSeconds = 0.4;
  static const double settleSeconds = 0.2;
  static const double stampPeriod = 0.7;

  static double f(double unit) =>
      unit <= 0 ? 0.3 : math.min(0.3, rideSeconds / unit);

  /// ONE belt speed for both rides, and a TRAIN at the changeover: the
  /// outgoing crate leaves the centre at wrap and the incoming one enters
  /// from off-screen at the same instant, at the same speed -- a constant
  /// gap apart, so the newcomer settles into the oven exactly as the old
  /// crate clears. No queueing at the mouth: one continuous flow.
  static double _v(double w, double crateW) =>
      (w / 2 + crateW + 6) / rideSeconds;

  /// The active crate: rides the whole left half at belt speed, landing
  /// in the oven at the end of the ride window, then parks.
  static double currentX(double p, double w, double crateW, double unit) {
    final fi = f(unit);
    if (p < fi) {
      return (-crateW - 6) + (p / fi) * rideSeconds * _v(w, crateW);
    }
    return w / 2;
  }

  /// The previous unit's crate riding out, or null once it is gone.
  static double? outgoingX(double p, double w, double crateW, double unit) {
    final fi = f(unit);
    if (p >= fi) return null;
    return w / 2 + (p / fi) * rideSeconds * _v(w, crateW);
  }

  static List<double> crates(
    double p,
    double w,
    double crateW,
    double unit, {
    required bool hasPrev,
  }) {
    final xs = <double>[currentX(p, w, crateW, unit)];
    if (hasPrev) {
      final out = outgoingX(p, w, crateW, unit);
      if (out != null) xs.add(out);
    }
    return xs;
  }

  /// The load dips into the crate right after parking.
  static double sinkK(double p, double unit) {
    final t = (p - f(unit)) * unit;
    return t <= 0 ? 0 : (t / settleSeconds).clamp(0.0, 1.0);
  }

  /// The product climbs out just before the unit wraps.
  static double riseK(double p, double unit) {
    if (unit <= 0) return 0;
    final t = (p - 1) * unit + settleSeconds;
    return t <= 0 ? 0 : (t / settleSeconds).clamp(0.0, 1.0);
  }

  static bool pressing(double p, double unit) => p > f(unit);

  static double pressSeconds(double p, double unit) {
    final t = (p - f(unit)) * unit;
    return t < 0 ? 0 : t;
  }

  /// The press extension 0..1, stamping on a steady beat.
  static double piston(double pressSecs) {
    final ph = (pressSecs % stampPeriod) / stampPeriod;
    return ph < 0.6 ? math.sin(math.pi * ph / 0.6) : 0.0;
  }

  /// The spark envelope 0..1 right after each impact.
  static double spark(double pressSecs) {
    final ph = (pressSecs % stampPeriod) / stampPeriod;
    if (ph < 0.3 || ph > 0.55) return 0;
    return (ph - 0.3) / 0.25;
  }
}

/// The freight: input icons peek from the arriving and staged crates,
/// duck under the press, and the product rides out in the previous
/// unit's crate. Icons are handed in, never drawn here.
class _ConveyorFreight extends StatelessWidget {
  const _ConveyorFreight({
    required this.clock,
    required this.phase,
    required this.unitSeconds,
    required this.crateW,
    required this.hasPrev,
    required this.doubled,
    required this.frozen,
    required this.inputs,
    required this.product,
  });

  final ValueNotifier<double> clock;
  final ValueNotifier<double> phase;

  /// True while the line is paused or starving: the frame holds still.
  final bool frozen;

  /// The outgoing crate carries TWO products this unit -- the duplicate
  /// chance, played out where the player can see it.
  final bool doubled;
  final double unitSeconds;
  final double crateW;
  final bool hasPrev;
  final List<Widget> inputs;
  final Widget product;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final beltY = constraints.maxHeight - 12;
        return AnimatedBuilder(
          animation: Listenable.merge([clock, phase]),
          builder: (context, _) {
            final p = phase.value;
            final sink = _BeltStory.sinkK(p, unitSeconds);
            final rise = _BeltStory.riseK(p, unitSeconds);
            final children = <Widget>[];

            void batchIcons(double cx, {required double drop, double bob = 0}) {
              for (var i = 0; i < inputs.length; i++) {
                children.add(
                  Positioned(
                    left: cx - crateW / 2 + 5 + i * 13,
                    top:
                        (beltY - 21) +
                        drop +
                        bob * math.sin(clock.value * 2.6 + i * 1.7),
                    child: inputs[i],
                  ),
                );
              }
            }

            if (hasPrev) {
              final out = _BeltStory.outgoingX(p, w, crateW, unitSeconds);
              if (out != null) {
                if (doubled) {
                  children.add(
                    Positioned(left: out - 15, top: beltY - 22, child: product),
                  );
                  children.add(
                    Positioned(left: out + 1, top: beltY - 22, child: product),
                  );
                } else {
                  children.add(
                    Positioned(left: out - 7, top: beltY - 22, child: product),
                  );
                }
              }
            }
            if (sink < 1) {
              batchIcons(
                _BeltStory.currentX(p, w, crateW, unitSeconds),
                drop: sink * 12,
                bob: frozen || sink > 0 ? 0 : 1.2,
              );
            }
            if (rise > 0) {
              children.add(
                Positioned(
                  left: w / 2 - 7,
                  top: (beltY - 10) - rise * 12,
                  child: Opacity(opacity: rise, child: product),
                ),
              );
            }
            return Stack(clipBehavior: Clip.hardEdge, children: children);
          },
        );
      },
    );
  }
}

/// The layer OVER the freight: every crate's front wall, the press ram,
/// the sparks, and the housing's front panels the crates ride behind.
class _ConveyorFront extends CustomPainter {
  _ConveyorFront({
    required this.clock,
    required this.phase,
    required this.unitSeconds,
    required this.output,
    required this.crateW,
    required this.hasPrev,
    required this.doubled,
  }) : super(repaint: phase);

  final ValueNotifier<double> clock;
  final ValueNotifier<double> phase;
  final double unitSeconds;
  final Color output;
  final double crateW;
  final bool hasPrev;

  /// The outgoing crate won the duplicate roll: it carries a gold x2
  /// stamp on its wall, so the win stays visible after the golden beat.
  final bool doubled;

  @override
  void paint(Canvas canvas, Size size) {
    final p = phase.value;
    final w = size.width;
    final beltY = size.height - 12;

    void crateWall(double cx, {bool stamped = false}) {
      final crate = Rect.fromLTWH(cx - crateW / 2, beltY - 13, crateW, 13);
      canvas.drawRect(crate, Paint()..color = Palette.card);
      canvas.drawRect(
        crate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = stamped
              ? Palette.gold.withValues(alpha: 0.75)
              : Palette.edge,
      );
      final seam = Paint()
        ..strokeWidth = 1
        ..color = Palette.lineBar;
      for (var i = 1; i < 3; i++) {
        final sx = crate.left + crate.width * i / 3;
        canvas.drawLine(
          Offset(sx, crate.top + 2),
          Offset(sx, crate.bottom - 2),
          seam,
        );
      }
      if (stamped) {
        final mark = TextPainter(
          text: TextSpan(
            text: '×2',
            style: AppText.display(
              7,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        mark.paint(
          canvas,
          crate.center - Offset(mark.width / 2, mark.height / 2),
        );
      }
    }

    // crates() lists the active crate first and the outgoing one second:
    // only the outgoing crate can carry the stamp -- the active one has
    // not rolled yet.
    final xs = _BeltStory.crates(p, w, crateW, unitSeconds, hasPrev: hasPrev);
    for (var i = 0; i < xs.length; i++) {
      crateWall(xs[i], stamped: doubled && i == 1);
    }

    if (_BeltStory.pressing(p, unitSeconds)) {
      final pressSecs = _BeltStory.pressSeconds(p, unitSeconds);
      final ext = _BeltStory.piston(pressSecs);
      final mx = w / 2;
      const shaftTop = 27.0;
      final restBottom = beltY - 50 + shaftTop + 2;
      final crateTop = beltY - 13;
      final headBottom = restBottom + ext * ((crateTop - 2) - restBottom);
      canvas.drawRect(
        Rect.fromLTRB(mx - 3.5, beltY - 50 + shaftTop, mx + 3.5, headBottom),
        Paint()..color = Palette.edge,
      );
      canvas.drawRect(
        Rect.fromLTRB(mx - 9, headBottom, mx + 9, headBottom + 3.5),
        Paint()..color = Palette.textMuted,
      );
      final sk = _BeltStory.spark(pressSecs);
      if (sk > 0) {
        final ink = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = output.withValues(alpha: (1 - sk) * 0.85);
        final r0 = 4 + sk * 11;
        for (var i = 0; i < 6; i++) {
          final a = -math.pi * (0.15 + 0.7 * i / 5);
          final from = Offset(
            mx + math.cos(a) * r0,
            crateTop + math.sin(a) * r0,
          );
          final to = Offset(
            mx + math.cos(a) * (r0 + 3.5 * (1 - sk)),
            crateTop + math.sin(a) * (r0 + 3.5 * (1 - sk)),
          );
          canvas.drawLine(from, to, ink);
        }
      }
    }

    // The machine's FRONT: two panels over the belt zone with an
    // inspection slot between them -- the crates ride in and out BEHIND
    // them, so the oven visibly swallows and releases the boxes.
    final mx = w / 2;
    final top = beltY - 50 + 26;
    final bottom = beltY + 8;
    final panel = Paint()..color = Palette.shell;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.edge;
    final leftPanel = Rect.fromLTRB(mx - 24, top, mx - 13, bottom);
    final rightPanel = Rect.fromLTRB(mx + 13, top, mx + 24, bottom);
    canvas.drawRect(leftPanel, panel);
    canvas.drawRect(rightPanel, panel);
    canvas.drawLine(leftPanel.topRight, leftPanel.bottomRight, edge);
    canvas.drawLine(rightPanel.topLeft, rightPanel.bottomLeft, edge);
    canvas.drawLine(leftPanel.topLeft, leftPanel.bottomLeft, edge);
    canvas.drawLine(rightPanel.topRight, rightPanel.bottomRight, edge);
  }

  @override
  bool shouldRepaint(_ConveyorFront old) =>
      old.output != output ||
      old.crateW != crateW ||
      old.hasPrev != hasPrev ||
      old.doubled != doubled;
}
