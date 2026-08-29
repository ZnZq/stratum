import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'gauge.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'tokens.dart';

/// The two rooms of the trade post.
enum TradeMode { sell, requests }

/// Trade: where the shaft's haul becomes credits.
///
/// Prices are fixed by design, so nothing here is about timing -- the sell
/// room is a settings panel (what sells, what share of it) with one honest
/// button, and the requests room is the only place a premium exists.
class TradeScreen extends StatefulWidget {
  const TradeScreen({required this.game, super.key});

  final Game game;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  TradeMode _mode = TradeMode.sell;
  ResourceId _picked = ResourceId.regolith;

  /// A wall clock, not a ticker: request timers keep running through pause,
  /// exactly like the drift they share a nature with, so the countdowns must
  /// not freeze behind the pause glass.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    widget.game.sim.syncRequests(DateTime.now().millisecondsSinceEpoch);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      widget.game.sim.syncRequests(DateTime.now().millisecondsSinceEpoch);
      // Standing in the room reads the news as it arrives.
      if (_mode == TradeMode.requests) widget.game.markRequestsSeen();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.game.sim;
    return Padding(
      // 12 at the foot to match the sides: the mode strip's corner cuts
      // run parallel to the frame's, and an unequal inset read as the whole
      // strip sitting a shade too low.
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: switch (_mode) {
              TradeMode.sell => _sellRoom(sim),
              TradeMode.requests => _requestRoom(sim),
            },
          ),
          const SizedBox(height: 8),
          // Seated on the screen's floor: square on top, struck only at its
          // outer bottom corners, the two rooms sharing the width evenly.
          HudChoice<TradeMode>(
            options: const [
              (TradeMode.sell, 'ПРОДАЖ'),
              (TradeMode.requests, 'ЗАПИТИ'),
            ],
            value: _mode,
            // The same dot the navigation wears, on the exact cell it means:
            // the tab said "something in Торгівля", this says "in ЗАПИТИ".
            marked: {if (widget.game.hasUnseenRequests) TradeMode.requests},
            onPick: (mode) => setState(() {
              _mode = mode;
              if (mode == TradeMode.requests) {
                widget.game.markRequestsSeen();
              }
            }),
            stretch: true,
            top: false,
            cut: 9,
            size: 9.5,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ sell

  Widget _sellRoom(PrototypeSimulation sim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: HudStat(
                label: 'кредити',
                corners: const HudCorners(topLeft: true),
                value: '${sim.stock.amount(ResourceId.credits)}',
                size: 17,
                accent: Palette.gold,
                colour: Palette.gold,
                labelColour: Palette.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudStat(
                label: 'за налаштуваннями',
                align: CrossAxisAlignment.end,
                corners: const HudCorners(topRight: true),
                value: '+${sim.sellAllYield()}',
                size: 17,
                accent: Palette.tech,
                colour: Palette.tech,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupCard(
                  sim: sim,
                  picked: _picked,
                  onPick: (id) => setState(() => _picked = id),
                  onChange: _poke,
                ),
                const SizedBox(height: 10),
                const _LockedGroup(label: 'МАТЕРІАЛИ'),
                const SizedBox(height: 10),
                const _LockedGroup(label: 'ПРОДУКЦІЯ'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        HudButton(
          onTap: sim.sellAllYield().isZero ? null : () => _poke(sim.sellAll),
          label: 'ПРОДАТИ ВСЕ · +${sim.sellAllYield()}',
          padding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ],
    );
  }

  void _poke(VoidCallback act) {
    act();
    setState(() {});
  }

  // -------------------------------------------------------------- requests

  Widget _requestRoom(PrototypeSimulation sim) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = sim.nextRequestAtMs - now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: HudStat(
                label: 'слоти',
                corners: const HudCorners(topLeft: true),
                value: '${sim.requests.length} / ${sim.requestSlots}',
                size: 17,
                accent: Palette.tech,
                colour: Palette.tech,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudStat(
                label: 'новий через',
                align: CrossAxisAlignment.end,
                corners: const HudCorners(topRight: true),
                value: _clockText(until),
                size: 17,
                accent: Palette.steel,
                colour: Palette.steel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final request in sim.requests) ...[
                  _RequestCard(sim: sim, request: request, onChange: _poke),
                  const SizedBox(height: 10),
                ],
                if (sim.requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'дошка порожня · новий запит уже в дорозі',
                        style: AppText.body(11, color: Palette.textFaint),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _clockText(int ms) {
    if (ms <= 0) return '0:00';
    final seconds = (ms / 1000).ceil();
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

/// The manual sale, filling whatever the share picker leaves.
///
/// The figure changes every tick, and a button sized by its own label would
/// drag the share picker around with it. The row hands it the leftover width
/// instead, and the label shrinks to fit rather than the box growing.
class _SellButton extends StatelessWidget {
  const _SellButton({required this.pay, required this.onTap});

  final BigDouble pay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HudButton(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          pay.isZero ? 'ПРОДАТИ' : 'ПРОДАТИ · +$pay',
          maxLines: 1,
          style: AppText.body(
            9,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
            color: onTap == null ? Palette.textFaint : Palette.gold,
          ),
        ),
      ),
    );
  }
}

/// Whether the sweep takes this position. Off is a routing choice, not a
/// state of the position -- the row around it keeps full colour.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.onTap, this.label});

  final bool on;
  final VoidCallback onTap;

  /// What the switch routes, said beside it: a bare toggle in a card full
  /// of controls does not say which of them it governs.
  final String? label;

  @override
  Widget build(BuildContext context) {
    // The knob is chamfered like its track and inset from the corners: a
    // square knob flush against the cut read as sticking out of the shape.
    final track = HudPlate(
      cut: 5,
      fill: on ? Palette.goldWell : Palette.shell,
      edge: on ? Palette.amber : Palette.lineBar,
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        width: 28,
        height: 12,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 110),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: HudPlate(
            cut: 3.5,
            fill: on ? Palette.gold : Palette.line,
            child: const SizedBox(width: 11, height: 11),
          ),
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: label == null
          ? track
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!.toUpperCase(),
                  style: AppText.body(
                    8,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: on ? Palette.gold : Palette.textFaint,
                  ),
                ),
                const SizedBox(width: 6),
                track,
              ],
            ),
    );
  }
}

class _SharePicker extends StatelessWidget {
  const _SharePicker({
    required this.sim,
    required this.id,
    required this.onChange,
  });

  final PrototypeSimulation sim;
  final ResourceId id;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    return HudChoice<int>(
      options: [
        for (final step in PrototypeSimulation.sellShares) (step, '$step%'),
      ],
      value: sim.sellShareOf(id).value,
      onPick: (step) => onChange(() => sim.sellShareOf(id).value = step),
      cut: 5,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
    );
  }
}

/// The grouped view: one card per family, the chosen member's settings on
/// top, the members as a picker row at the bottom.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.sim,
    required this.picked,
    required this.onPick,
    required this.onChange,
  });

  final PrototypeSimulation sim;
  final ResourceId picked;
  final ValueChanged<ResourceId> onPick;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[picked]!;
    final selling = sim.sellingOf(picked).value;
    final pay = sim.sellYield(picked);
    // The card's edge answers "does this shelf pay?": grey when the group
    // is off or nothing in it is switched on.
    final live = PrototypeSimulation.priceTable.any(
      (row) => sim.sellsInSweep(row.id),
    );
    return HudBox(
      cut: 11,
      fill: Palette.bar.withValues(alpha: 0.6),
      edge: live ? Palette.gold.withValues(alpha: 0.55) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'РЕСУРСИ · ${PrototypeSimulation.priceTable.length}',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              // The shelf's own switch: it does NOT rewrite what each
              // position chose, so flipping it back restores the set-up.
              _Toggle(
                label: 'вся група',
                on: sim.sellingResources.value,
                onTap: () => onChange(
                  () =>
                      sim.sellingResources.value = !sim.sellingResources.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              _Toggle(
                label: 'в продаж',
                on: selling,
                onTap: () =>
                    onChange(() => sim.sellingOf(picked).value = !selling),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Readouts, not a byline: the stock and the unit price are the two
          // numbers the sale is made of, and they deserve the house plate.
          // The left plate is HEADED BY THE POSITION ITSELF -- the amount
          // needs no word "склад" once the plate names what it counts.
          Row(
            children: [
              Expanded(
                child: HudStat(
                  label: style.label,
                  corners: const HudCorners(topLeft: true, bottomLeft: true),
                  value: '${sim.stock.amount(picked)}',
                  size: 13,
                  accent: style.colour,
                  colour: style.colour,
                  labelColour: style.colour,
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: HudStat(
                  label: 'ціна за 1',
                  align: CrossAxisAlignment.end,
                  corners: const HudCorners(topRight: true, bottomRight: true),
                  value: '${sim.sellPrice(picked)} кр',
                  size: 13,
                  accent: Palette.gold,
                  colour: Palette.gold,
                  labelColour: Palette.gold,
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SharePicker(sim: sim, id: picked, onChange: onChange),
              const SizedBox(width: 8),
              Expanded(
                child: _SellButton(
                  pay: pay,
                  onTap: pay.isZero
                      ? null
                      : () => onChange(() => sim.sellPosition(picked)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final row in PrototypeSimulation.priceTable) ...[
                if (row.id != PrototypeSimulation.priceTable.first.id)
                  const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(row.id),
                  // Chamfered, not rounded: the well sits on a HUD panel,
                  // and a rounded box was the app dialect leaking back in.
                  // Amber answers the EFFECTIVE question -- does this one
                  // actually go in the sweep: its own switch and the
                  // shelf's together.
                  child: HudPlate(
                    cut: 7,
                    fill: row.id == picked ? Palette.goldWell : Palette.shell,
                    edge: sim.sellsInSweep(row.id)
                        ? Palette.amber
                        : Palette.lineBar,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(child: ResourceIcon(row.id, size: 17)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A family the game has not built yet. Honest about why it is shut.
class _LockedGroup extends StatelessWidget {
  const _LockedGroup({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HudBox(
      cut: 11,
      fill: Palette.shell.withValues(alpha: 0.5),
      edge: Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.textFaint,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                'відкриється з крафтом',
                style: AppText.body(9, color: Palette.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var slot = 0; slot < 3; slot++) ...[
                if (slot > 0) const SizedBox(width: 6),
                const HudPlate(
                  cut: 7,
                  fill: Palette.shell,
                  edge: Palette.lineBar,
                  child: SizedBox(width: 30, height: 30),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One posted request: its shopping list with stock bars, its payout, and
/// the time it has left.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.sim,
    required this.request,
    required this.onChange,
  });

  final PrototypeSimulation sim;
  final TradeRequest request;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = request.expiresAtMs - now;
    final frac = (left / PrototypeSimulation.requestLifetimeMs).clamp(0.0, 1.0);
    final hot = left < 60 * 1000;
    final live = sim.canFulfil(request);
    final tone = hot ? Palette.alarm : Palette.tech;

    return HudBox(
      cut: 11,
      fill: Palette.bar.withValues(alpha: 0.6),
      edge: live ? Palette.gold.withValues(alpha: 0.55) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final need in request.needs) ...[
            if (need != request.needs.first) const SizedBox(height: 7),
            _NeedLine(sim: sim, need: need),
          ],
          const SizedBox(height: 9),
          // A POUR, not cells: time drains continuously, and drawn in the
          // same cell language as the stock bars the clock was one more teal
          // strip in a stack of three -- unreadable without the digits.
          SizedBox(
            height: 13,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Square ends: the pour keeps its nature, but a pill
                // among chamfers was the one round thing in the card.
                Gauge(
                  fraction: frac,
                  height: 13,
                  radius: 0,
                  fill: tone.withValues(alpha: 0.4),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Transform.translate(
                      offset: const Offset(0, 0.8),
                      child: Text(
                        _left(left),
                        style: AppText.display(
                          8.5,
                          weight: FontWeight.w700,
                          color: Palette.text,
                          height: 1,
                        ).copyWith(shadows: AppText.halo),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // Payout, premium and the act in one rank. The plates are fully
          // SQUARE: the card already cuts its own bottom corners a dozen
          // pixels out, and an inner cut beside an outer one is the double
          // diagonal the house rule forbids -- a nested block does not
          // repeat the corners of what holds it. The button keeps its
          // chamfer: that shape means "pressable" everywhere in the game,
          // and beside square plates it now reads as the one control here.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: HudStat(
                    label: 'заробіток',
                    corners: HudCorners.none,
                    value: '+${sim.requestPayout(request)}',
                    size: 13,
                    accent: Palette.gold,
                    colour: Palette.gold,
                    labelColour: Palette.gold,
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                  ),
                ),
                Expanded(
                  child: HudStat(
                    label: 'премія',
                    corners: HudCorners.none,
                    value: '+${(request.premium * 100).round()}%',
                    size: 13,
                    accent: Palette.tech,
                    colour: Palette.tech,
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: HudButton(
                    onTap: live
                        ? () => onChange(() => sim.fulfilRequest(request))
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          live ? 'ВИКОНАТИ' : 'НЕ ВИСТАЧАЄ',
                          maxLines: 1,
                          style: AppText.body(
                            9,
                            weight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: live ? Palette.gold : Palette.textFaint,
                          ),
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

  static String _left(int ms) {
    if (ms <= 0) return '0:00';
    final seconds = (ms / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// One ingredient of a request, carrying its own stock bar: how much of it
/// is already on hand, in the same cell language as the timer below.
class _NeedLine extends StatelessWidget {
  const _NeedLine({required this.sim, required this.need});

  final PrototypeSimulation sim;
  final ({ResourceId id, BigDouble amount}) need;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[need.id]!;
    final held = sim.stock.amount(need.id);
    final frac = need.amount.isZero
        ? 1.0
        : (held / need.amount).toDouble().clamp(0.0, 1.0);
    final full = frac >= 1;
    final tone = full ? Palette.tech : Palette.amber;
    // The line, and a hairline of it underneath: how much of the ASKED
    // amount is on hand, in the RESOURCE's own colour -- the bar belongs to
    // the ingredient, and the verdict already lives in the figure (teal
    // covered, amber short). Thin on purpose: it underscores the fact
    // rather than competing with the timer.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ResourceIcon(need.id, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(10, color: Palette.textDim),
              ),
            ),
            Text(
              '$held / ${need.amount}',
              style: AppText.display(
                10,
                weight: FontWeight.w600,
                color: tone,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Gauge(
          fraction: frac,
          height: 3,
          fill: style.colour.withValues(alpha: full ? 0.55 : 0.9),
        ),
      ],
    );
  }
}
