import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'tokens.dart';
import 'resource_icon.dart';

/// Financing: the backer's answer to proven turnover.
///
/// Rounds are raised against lifetime turnover and pay tranches; tranches
/// pour into the multipliers of WHAT SELLS -- the fund table is the price
/// list plus credits themselves, and nothing else: prestige fuel levels
/// through the trees, not through the backer. Spending is itself rewarded:
/// every poured tranche compounds the global multiplier, and enough spending
/// climbs a RANK, which lifts every cap and compounds again.
class FinancingSheet extends StatelessWidget {
  const FinancingSheet({required this.game, required this.onClose, super.key});

  final Game game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final free = sim.tranchesFree;
    return HudModal(
      icon: Ic.stats,
      title: 'ФІНАНСУВАННЯ',
      accent: Palette.gold,
      anchor: ModalAnchor.stretch,
      onClose: onClose,
      trailing: Text(
        'РАУНД ${sim.financeRound}',
        style: AppText.display(
          13,
          weight: FontWeight.w700,
          color: Palette.gold,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: HudStat(
                  label: 'оборот симуляції',
                  corners: const HudCorners(topLeft: true),
                  value: '${sim.creditsEarned.value}',
                  size: 15,
                  accent: Palette.credit,
                  colour: Palette.credit,
                  labelColour: Palette.credit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudStat(
                  label: 'вільні транші',
                  align: CrossAxisAlignment.end,
                  corners: const HudCorners(topRight: true),
                  value: '$free',
                  size: 15,
                  accent: free > 0 ? Palette.tech : Palette.steel,
                  colour: free > 0 ? Palette.tech : Palette.steel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // No round bar here: the strip's gauge is visible right above the
          // sheet and says exactly this -- and the thirty pixels it cost
          // were the thirty the last card was overflowing by.

          // The rank block: what spending itself has bought.
          HudBox(
            cut: 9,
            fill: Palette.shell.withValues(alpha: 0.6),
            edge: Palette.gold.withValues(alpha: 0.4),
            padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'РАНГ ${sim.financeRank}',
                      style: AppText.body(
                        9,
                        weight: FontWeight.w800,
                        color: Palette.gold,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'множник ×${sim.fundGlobalScale.toDouble().toStringAsFixed(2)}',
                      style: AppText.display(
                        12,
                        weight: FontWeight.w700,
                        color: Palette.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'кожен влитий транш ×1.01 до всього · ранг ×1.02 і +10 '
                  'до стель рівнів',
                  style: AppText.body(8.5, color: Palette.textFaint),
                ),
                const SizedBox(height: 7),
                HudProgress(
                  fraction: sim.rankProgress,
                  height: 8,
                  accent: Palette.gold,
                  reading:
                      '${sim.tranchesSpent} /'
                      ' ${PrototypeSimulation.rankThreshold(sim.financeRank + 1)}',
                  place: HudReading.inside,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final row in PrototypeSimulation.fundTable) ...[
            _FundRow(sim: sim, id: row.id, free: free, onInvest: _invest),
            if (row != PrototypeSimulation.fundTable.last)
              const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  void _invest(ResourceId id) {
    if (game.sim.investTranche(id)) game.pokeListeners();
  }
}

/// One funded lane: its face, its level against the cap, its multiplier,
/// and the tap that feeds it.
class _FundRow extends StatelessWidget {
  const _FundRow({
    required this.sim,
    required this.id,
    required this.free,
    required this.onInvest,
  });

  final PrototypeSimulation sim;
  final ResourceId id;
  final int free;
  final ValueChanged<ResourceId> onInvest;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    final level = sim.fundingOf(id).value;
    final cap = sim.fundCap;
    final atCap = level >= cap;
    final cost = sim.investCost(id);
    // The owner's own sketch: icon and button as full-height columns, three
    // lines of fact between them -- name, the total the lane wears, and the
    // step beside the level walk. No bar: three figures say it all.
    return HudBox(
      cut: 9,
      fill: Palette.shell.withValues(alpha: 0.6),
      edge: level > 0 ? style.colour.withValues(alpha: 0.5) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(10, 5, 7, 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ResourceIcon(id, size: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    style.label,
                    style: AppText.body(
                      9.5,
                      weight: FontWeight.w700,
                      color: style.colour,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    '×${sim.fundScaleOf(id)}',
                    style: AppText.display(
                      14,
                      weight: FontWeight.w700,
                      color: level > 0 ? style.colour : Palette.textDim,
                      height: 1.05,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '×${PrototypeSimulation.fundStep(id).toStringAsFixed(2)} / рів.',
                        style: AppText.body(8.5, color: Palette.textFaint),
                      ),
                      // The walk sits flush right, by request: the numbers
                      // column-align across the stack of cards.
                      const Spacer(),
                      Text(
                        '$level / $cap',
                        style: AppText.display(
                          9,
                          weight: FontWeight.w600,
                          color: atCap ? style.colour : Palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            HudButton(
              holdRepeat: true,
              onTap: sim.canInvest(id) ? () => onInvest(id) : null,
              accent: style.colour,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  atCap ? 'СТЕЛЯ' : 'ВЛИТИ${String.fromCharCode(10)}$cost ТР',
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    9,
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                    height: 1.25,
                    color: sim.canInvest(id) ? style.colour : Palette.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
