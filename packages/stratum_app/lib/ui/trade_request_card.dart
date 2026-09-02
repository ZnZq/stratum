import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'gauge.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'tokens.dart';
import 'resource_icon.dart';
import 'clock_text.dart';

/// One posted request: its shopping list with stock bars, its payout, and
/// the time it has left.
class RequestCard extends StatelessWidget {
  const RequestCard({
    required this.sim,
    required this.request,
    required this.onChange,
    super.key,
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
                        mmssClock(left),
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
