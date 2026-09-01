import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'craft_clock.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'resource_style.dart';
import 'tokens.dart';

/// The picker, rethought as MENU + PASSPORT: a light list of what the line
/// could make (icon, name, a sufficiency lamp -- no prices), and one card
/// below it where ALL the specifics of the chosen recipe live: inputs with
/// the stock's runway, time and yield at the line's level, the duplicate
/// odds, the compression track and the run mode. Reading order: pick,
/// read the passport, launch.
class CraftRecipeSheet extends StatefulWidget {
  const CraftRecipeSheet({
    required this.game,
    required this.index,
    required this.onClose,
    required this.onChange,
    super.key,
  });

  final Game game;
  final int index;
  final VoidCallback onClose;
  final ValueChanged<VoidCallback> onChange;

  @override
  State<CraftRecipeSheet> createState() => _CraftRecipeSheetState();
}

class _CraftRecipeSheetState extends State<CraftRecipeSheet> {
  ResourceId? _picked;
  bool _endless = true;
  int _n = 100;
  late int _tier;

  CraftLine get _line => widget.game.sim.craftLines[widget.index];

  @override
  void initState() {
    super.initState();
    final line = _line;
    _picked = line.recipe.value;
    _endless = line.limit.value < 0;
    if (line.limit.value > 0) _n = line.limit.value;
    _tier = line.tier.value;
  }

  /// The pace a NEW job starts at: the speed track alone. The line's live
  /// speedFactor carries the boost stacks, and assigning resets those --
  /// the passport must not promise a warm-up the job will not inherit.
  double get _jobSpeed =>
      (1 + craftSpeedStep * _line.speedLevel.value) * craftGameSpeed;

  /// The order stepper: minus under one unit falls back to AUTO, plus from
  /// AUTO starts a fresh finite order at the step.
  void _bumpN(int delta) {
    setState(() {
      if (_endless) {
        if (delta <= 0) return;
        _endless = false;
        _n = delta;
        return;
      }
      final next = _n + delta;
      if (next < 1) {
        _endless = true;
      } else {
        _n = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HudModal(
      icon: Ic.craft,
      title: 'РЕЦЕПТ І РЕЖИМ',
      accent: Palette.gold,
      anchor: ModalAnchor.fill,
      onClose: widget.onClose,
      trailing: Text(
        'ЛІНІЯ ${widget.index + 1}',
        style: AppText.display(
          11,
          weight: FontWeight.w700,
          color: Palette.textMuted,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          _section('матеріали', Palette.tech),
          _menuGrid(ResourceShelf.materials),
          const SizedBox(height: 5),
          _section('будівництво', Palette.steel),
          _menuGrid(ResourceShelf.building),
          const SizedBox(height: 5),
          _section('технології', Palette.gold),
          _menuGrid(ResourceShelf.tech),
          const SizedBox(height: 7),
          Expanded(
            child: _picked == null
                ? const _EmptyPassport()
                : _Passport(
                    game: widget.game,
                    recipe: craftRecipeOf(_picked)!,
                    tier: _tier,
                    tierCap: _line.tierCap.value,
                    speed: _jobSpeed,
                    endless: _endless,
                    n: _n,
                    onTier: (v) => setState(() => _tier = v),
                    onBump: _bumpN,
                    onAuto: () => setState(() => _endless = true),
                  ),
          ),
          const SizedBox(height: 6),
          _launchButton(),
        ],
      ),
    );
  }

  /// The menu: one light row per recipe -- what it is and whether the
  /// stock can start it at the chosen level. Prices live in the passport.
  Widget _menuGrid(ResourceShelf shelf) {
    final rows = [
      for (final recipe in craftTable)
        if (resourceStyles[recipe.output]!.shelf == shelf) recipe,
    ];
    return Row(
      children: [
        for (final recipe in rows) ...[
          if (recipe != rows.first) const SizedBox(width: 5),
          Expanded(
            child: _MenuCell(
              recipe: recipe,
              picked: _picked == recipe.output,
              onTap: () => setState(() => _picked = recipe.output),
            ),
          ),
        ],
      ],
    );
  }

  Widget _launchButton() {
    final style = _picked == null ? null : resourceStyles[_picked!]!;
    String label;
    if (_picked == null) {
      label = 'ОБЕРИ РЕЦЕПТ';
    } else {
      final recipe = craftRecipeOf(_picked)!;
      final yieldPer = BigDouble.fromNum(
        recipe.baseYield * math.pow(craftYieldStep, _tier),
      );
      final seconds = math.max(
        craftMinSeconds,
        recipe.baseSeconds * math.pow(craftTimeStep, _tier) / _jobSpeed,
      );
      label =
          'ЗАПУСТИТИ · ${style!.label.toUpperCase()} · '
          '+$yieldPer / ${craftClock(seconds)}'
          '${_endless ? '' : ' · $_n шт'}';
    }
    return HudButton(
      onTap: _picked == null ? null : _launch,
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Center(
        child: Text(
          label,
          style: AppText.body(
            9.5,
            weight: FontWeight.w800,
            letterSpacing: 1.4,
            color: _picked == null ? Palette.textFaint : Palette.gold,
          ),
        ),
      ),
    );
  }

  void _launch() {
    widget.onChange(() {
      widget.game.sim.assignCraftRecipe(
        widget.index,
        _picked,
        limit: _endless ? -1 : _n,
        tier: _tier,
      );
    });
    widget.onClose();
  }

  Widget _section(String label, Color colour) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: colour,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: colour.withValues(alpha: 0.15)),
          ),
        ),
      ],
    ),
  );
}

/// One recipe on the menu: icon and name, nothing else -- the specifics,
/// affordability included, are the passport's job.
class _MenuCell extends StatelessWidget {
  const _MenuCell({
    required this.recipe,
    required this.picked,
    required this.onTap,
  });

  final CraftRecipe recipe;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[recipe.output]!;
    return HudTap(
      onTap: onTap,
      cut: 5,
      corners: HudCorners.centred,
      child: HudPlate(
        cut: 5,
        fill: picked
            ? Palette.goldWell.withValues(alpha: 0.7)
            : const Color(0x00000000),
        edge: picked ? Palette.gold.withValues(alpha: 0.55) : Palette.lineBar,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
        child: Column(
          children: [
            ResourceIcon(recipe.output, size: 15),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                style.label.toUpperCase(),
                style: AppText.body(
                  7.5,
                  weight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: picked ? style.colour : Palette.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The passport of the chosen recipe: every figure the launch decision
/// needs, in one card, recomputed live as the level changes. The figures
/// the level moves FLINCH on a change -- the energy plate's pulse.
class _Passport extends StatelessWidget {
  const _Passport({
    required this.game,
    required this.recipe,
    required this.tier,
    required this.tierCap,
    required this.speed,
    required this.endless,
    required this.n,
    required this.onTier,
    required this.onBump,
    required this.onAuto,
  });

  final Game game;
  final CraftRecipe recipe;
  final int tier;
  final int tierCap;
  final double speed;
  final bool endless;
  final int n;
  final ValueChanged<int> onTier;
  final ValueChanged<int> onBump;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[recipe.output]!;
    final costScale = math.pow(craftCostStep, tier).toDouble();
    final seconds = math.max(
      craftMinSeconds,
      recipe.baseSeconds * math.pow(craftTimeStep, tier) / speed,
    );
    final yieldPer = BigDouble.fromNum(
      recipe.baseYield * math.pow(craftYieldStep, tier),
    );
    return HudPlate(
      cut: 5,
      fill: Palette.well.withValues(alpha: 0.55),
      edge: Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ResourceIcon(recipe.output, size: 18),
              const SizedBox(width: 8),
              Text(
                style.label.toUpperCase(),
                style: AppText.body(
                  11,
                  weight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: style.colour,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // The inputs as a panel of HudStat plates, seam to seam: only
          // the block's outer corners are struck (the group rule).
          // The inputs as a GRID of stat plates, two to a row (owner's
          // rule); only the block's outer corners are struck. Each row is
          // IntrinsicHeight, not bare stretch -- the unbounded-column
          // lesson.
          ..._inputGrid(costScale),
          const Spacer(),
          const HudRule(),
          const SizedBox(height: 6),
          Row(
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
              const Spacer(),
              _TierStep(
                glyph: '−',
                enabled: tier > 0,
                onTap: () => onTier(tier - 1),
              ),
              SizedBox(
                width: 24,
                child: Center(
                  child: Text(
                    '$tier',
                    style: AppText.display(
                      12,
                      weight: FontWeight.w700,
                      color: Palette.text,
                    ),
                  ),
                ),
              ),
              _TierStep(
                glyph: '+',
                enabled: tier < tierCap,
                onTap: () => onTier(tier + 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The ladder in the board's own language: chosen cells lit,
          // bought ones banked, the rest dark.
          Row(
            children: [
              for (var i = 0; i < craftTierCapMax; i++) ...[
                if (i > 0) const SizedBox(width: 1.5),
                Expanded(
                  child: SizedBox(
                    height: 4.5,
                    child: ColoredBox(
                      color: i < tier
                          ? Palette.gold
                          : i < tierCap
                          ? Palette.goldWell
                          : Palette.card,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'РЕЖИМ',
                style: AppText.body(
                  7.5,
                  weight: FontWeight.w700,
                  color: Palette.textFaint,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              // A fixed box: the infinity glyph's line is shorter than
              // the digits', and a resizing reading bounces the sheet.
              SizedBox(
                height: 16,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    endless ? '\u221E' : '$n шт',
                    style: AppText.display(
                      12,
                      weight: FontWeight.w700,
                      color: Palette.gold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ModeStepper(endless: endless, onBump: onBump, onAuto: onAuto),
          const SizedBox(height: 8),
          // The summary the launch is judged by, right above the button:
          // one plate for the craft, one for the pace it adds up to.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: HudStat(
                    label: 'ЗА КРАФТ',
                    corners: const HudCorners(topLeft: true, bottomLeft: true),
                    cut: 7,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                    child: _Flinch(
                      trigger: tier,
                      // One Text.rich, not a baseline Row: inline spans
                      // share a baseline by the text engine itself, with
                      // no Row conventions to drift.
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '+$yieldPer',
                              style: AppText.display(
                                12,
                                weight: FontWeight.w700,
                                color: Palette.tech,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${craftClock(seconds)}',
                              style: AppText.display(
                                9.5,
                                color: Palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: HudStat(
                    label: 'ТЕМП',
                    corners: const HudCorners(
                      topRight: true,
                      bottomRight: true,
                    ),
                    cut: 7,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                    child: _Flinch(
                      trigger: tier,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '+${_rateText(yieldPer.toDouble() / seconds)}',
                              style: AppText.display(
                                12,
                                weight: FontWeight.w700,
                                color: Palette.tech,
                              ),
                            ),
                            TextSpan(
                              text: ' / с',
                              style: AppText.display(
                                9.5,
                                color: Palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The input plates, chunked two to a row. A lone plate on the last
  /// row takes the full width.
  List<Widget> _inputGrid(double costScale) {
    final entries = recipe.inputs.entries.toList();
    final rows = <List<MapEntry<ResourceId, double>>>[];
    for (var i = 0; i < entries.length; i += 2) {
      rows.add(entries.sublist(i, math.min(i + 2, entries.length)));
    }
    return [
      for (var r = 0; r < rows.length; r++) ...[
        if (r > 0) const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 4),
                Expanded(
                  child: _inputStat(
                    rows[r][c].key,
                    rows[r][c].value * costScale,
                    corners: HudCorners(
                      topLeft: r == 0 && c == 0,
                      topRight: r == 0 && c == rows[r].length - 1,
                      bottomLeft: r == rows.length - 1 && c == 0,
                      bottomRight:
                          r == rows.length - 1 && c == rows[r].length - 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  /// One input on a stat plate, quoted as X / Y: what a craft takes
  /// against what the shelf holds. The pair answers "can I?" without a
  /// lamp; the plate keeps the inputs in the game's readout language.
  Widget _inputStat(
    ResourceId id,
    double amount, {
    required HudCorners corners,
  }) {
    final need = BigDouble.fromNum(amount);
    final held = game.sim.stock.amount(id);
    final short = !held.gteWithTolerance(need);
    final style = resourceStyles[id]!;
    return HudStat(
      label: style.label,
      accent: style.colour,
      labelColour: style.colour.withValues(alpha: 0.85),
      corners: corners,
      cut: 7,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      child: _Flinch(
        trigger: tier,
        child: Row(
          children: [
            ResourceIcon(id, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$need',
                      style: AppText.display(
                        11,
                        weight: FontWeight.w700,
                        color: short ? Palette.amber : Palette.tech,
                      ),
                    ),
                    Text(
                      ' / $held',
                      style: AppText.display(
                        9,
                        color: short ? Palette.amber : Palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The line card's own rate format, so the promise reads identically
  /// on both sides of the launch: three decimals under one, two under
  /// ten, the house number style above.
  static String _rateText(double v) {
    if (v < 1) return v.toStringAsFixed(3);
    return v < 10
        ? v.toStringAsFixed(2)
        : '${BigDouble.fromNum(v)}';
  }

}

/// The energy plate's flinch, borrowed: whatever sits inside swells for a
/// beat when [trigger] changes. Transform.scale is paint-only, so the
/// sheet never reflows.
class _Flinch extends StatefulWidget {
  const _Flinch({required this.trigger, required this.child});

  final Object trigger;
  final Widget child;

  @override
  State<_Flinch> createState() => _FlinchState();
}

class _FlinchState extends State<_Flinch> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  );

  @override
  void didUpdateWidget(_Flinch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      // Gentler than the energy plate's 0.15: these sit on wide rows,
      // and a swell scales from the centre -- wide content throws its
      // ends around at an amplitude a lone figure carries fine.
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.05 * math.sin(math.pi * _pulse.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// The passport's empty seat: the card holds its place so the sheet does
/// not jump when the first recipe is picked.
class _EmptyPassport extends StatelessWidget {
  const _EmptyPassport();

  @override
  Widget build(BuildContext context) {
    return HudPlate(
      cut: 5,
      fill: Palette.well.withValues(alpha: 0.3),
      edge: Palette.lineBar,
      child: Center(
        child: Text(
          'обери рецепт у меню',
          style: AppText.body(9, color: Palette.textFaint),
        ),
      ),
    );
  }
}

/// The order-size stepper the owner asked for by shape:
/// [-100][-10][-1][AUTO][+1][+10][+100]. AUTO is the endless order.
class _ModeStepper extends StatelessWidget {
  const _ModeStepper({
    required this.endless,
    required this.onBump,
    required this.onAuto,
  });

  final bool endless;
  final ValueChanged<int> onBump;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, VoidCallback onTap, {bool lit = false}) =>
        Expanded(
          child: HudTap(
            onTap: onTap,
            child: ColoredBox(
              color: lit ? Palette.goldWell : const Color(0x00000000),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Text(
                    label,
                    style: AppText.display(
                      9,
                      weight: FontWeight.w700,
                      color: lit ? Palette.gold : Palette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    Widget seam() =>
        const SizedBox(width: 1, child: ColoredBox(color: Palette.lineBar));
    return HudPlate(
      cut: 5,
      fill: Palette.shell.withValues(alpha: 0.5),
      edge: Palette.line,
      padding: EdgeInsets.zero,
      // IntrinsicHeight, not bare stretch: the row sits in an unbounded
      // column, and stretched seams would be handed an infinite height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell('−100', () => onBump(-100)),
            seam(),
            cell('−10', () => onBump(-10)),
            seam(),
            cell('−1', () => onBump(-1)),
            seam(),
            cell('AUTO', onAuto, lit: endless),
            seam(),
            cell('+1', () => onBump(1)),
            seam(),
            cell('+10', () => onBump(10)),
            seam(),
            cell('+100', () => onBump(100)),
          ],
        ),
      ),
    );
  }
}

class _TierStep extends StatelessWidget {
  const _TierStep({
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
