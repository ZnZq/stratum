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

/// The picker: what the line will make AND how it will run, chosen in one
/// place. The run mode belongs to the order, so it is set here and worn on
/// the line only as a badge.
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
    final line = _line;
    final pickedStyle = _picked == null ? null : resourceStyles[_picked!]!;
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
          for (final recipe in craftTable)
            if (resourceStyles[recipe.output]!.shelf == ResourceShelf.materials)
              _RecipeRow(
                game: widget.game,
                recipe: recipe,
                tier: _tier,
                speed: line.speedFactor.value,
                picked: _picked == recipe.output,
                onTap: () => setState(() => _picked = recipe.output),
              ),
          const SizedBox(height: 3),
          _section('продукція', Palette.steel),
          for (final recipe in craftTable)
            if (resourceStyles[recipe.output]!.shelf == ResourceShelf.products)
              _RecipeRow(
                game: widget.game,
                recipe: recipe,
                tier: _tier,
                speed: line.speedFactor.value,
                picked: _picked == recipe.output,
                onTap: () => setState(() => _picked = recipe.output),
              ),
          const Spacer(),
          const HudRule(),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                'КОМПРЕСІЯ',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.textFaint,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 10),
              _TierStep(
                glyph: '−',
                enabled: _tier > 0,
                onTap: () => setState(() => _tier--),
              ),
              SizedBox(
                width: 26,
                child: Center(
                  child: Text(
                    '$_tier',
                    style: AppText.display(
                      13,
                      weight: FontWeight.w700,
                      color: Palette.text,
                    ),
                  ),
                ),
              ),
              _TierStep(
                glyph: '+',
                enabled: _tier < line.tierCap.value,
                onTap: () => setState(() => _tier++),
              ),
              const SizedBox(width: 5),
              Text(
                '/ ${line.tierCap.value}',
                style: AppText.display(9, color: Palette.textMuted),
              ),
              const Spacer(),
              Text(
                'вихід ×${1 << _tier} · ціни й час вище — на цьому рівні',
                style: AppText.body(7.5, color: Palette.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                'РЕЖИМ',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.textFaint,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 10),
              // A fixed box: the infinity glyph's line is shorter than the
              // digits', and a reading that resizes bounces the sheet.
              SizedBox(
                height: 18,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _endless ? '∞' : '$_n шт',
                    style: AppText.display(
                      13,
                      weight: FontWeight.w700,
                      color: Palette.gold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ModeStepper(
            endless: _endless,
            onBump: _bumpN,
            onAuto: () => setState(() => _endless = true),
          ),
          const SizedBox(height: 6),
          HudButton(
            onTap: _picked == null ? null : _launch,
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(
                _picked == null
                    ? 'ОБЕРИ РЕЦЕПТ'
                    : 'ЗАПУСТИТИ · ${pickedStyle!.label.toUpperCase()} · '
                          '${_endless ? '∞' : 'N $_n'}',
                style: AppText.body(
                  9.5,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _picked == null ? Palette.textFaint : Palette.gold,
                ),
              ),
            ),
          ),
        ],
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
    padding: const EdgeInsets.only(bottom: 3),
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

/// One recipe on the menu, quoting its inputs and craft time AT THE LINE'S
/// LEVEL -- the vitrine quotes the product, never the bare base.
class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.game,
    required this.recipe,
    required this.tier,
    required this.speed,
    required this.picked,
    required this.onTap,
  });

  final Game game;
  final CraftRecipe recipe;
  final int tier;
  final double speed;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[recipe.output]!;
    final costScale = math.pow(craftCostStep, tier).toDouble();
    final seconds = recipe.baseSeconds * math.pow(craftTimeStep, tier) / speed;
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
        padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
        child: Row(
          children: [
            ResourceIcon(recipe.output, size: 16),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label.toUpperCase(),
                    style: AppText.body(
                      9.5,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      color: style.colour,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        for (final entry in recipe.inputs.entries) ...[
                          if (entry.key != recipe.inputs.keys.first)
                            const SizedBox(width: 10),
                          _need(entry.key, entry.value * costScale),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${craftClock(seconds)} · +${_yield()}',
              style: AppText.display(9, color: Palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _yield() =>
      '${BigDouble.fromNum(recipe.baseYield * math.pow(craftYieldStep, tier))}';

  Widget _need(ResourceId id, double amount) {
    final need = BigDouble.fromNum(amount);
    final short = !game.sim.stock.has(id, need);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceIcon(id, size: 10),
        const SizedBox(width: 3),
        Text(
          '$need',
          style: AppText.display(
            9,
            color: short ? Palette.amber : Palette.tech,
          ),
        ),
      ],
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
