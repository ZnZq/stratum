import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'tokens.dart';

/// Financing: the backer's answer to proven turnover.
///
/// The AI raises ROUNDS against everything the simulation has ever earned --
/// income only, spending changes nothing -- and each closed round pays one
/// TRANCHE to pour into a budget line. The sheet is a statement, not a shop:
/// nothing here costs credits, the credits already paid by being earned.
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
      anchor: ModalAnchor.bottom,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: HudStat(
                  label: 'оборот симуляції',
                  corners: const HudCorners(topLeft: true),
                  value: '${sim.creditsEarned.value}',
                  size: 15,
                  accent: Palette.gold,
                  colour: Palette.gold,
                  labelColour: Palette.gold,
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
          const SizedBox(height: 12),
          HudProgress(
            fraction: sim.roundProgress,
            accent: Palette.gold,
            label: 'ДО РАУНДУ ${sim.financeRound + 1}',
            reading:
                '${sim.creditsEarned.value - sim.roundFloor(sim.financeRound)}'
                ' / ${sim.nextRoundCost}',
          ),
          const SizedBox(height: 14),
          for (final line in FundLine.values) ...[
            if (line != FundLine.values.first) const SizedBox(height: 8),
            _LineRow(sim: sim, line: line, free: free, onInvest: _invest),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _invest(FundLine line) {
    if (game.sim.investTranche(line)) game.pokeListeners();
  }
}

/// One budget line: what it multiplies, where it stands, and its tap.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.sim,
    required this.line,
    required this.free,
    required this.onInvest,
  });

  final PrototypeSimulation sim;
  final FundLine line;
  final int free;
  final ValueChanged<FundLine> onInvest;

  static const Map<FundLine, ({String name, String note, Color colour})>
  _faces = {
    FundLine.extraction: (
      name: 'ВИДОБУТОК',
      note: 'уся здобич, крім даних',
      colour: Palette.ore,
    ),
    FundLine.telemetry: (
      name: 'ТЕЛЕМЕТРІЯ',
      note: 'сирі дані',
      colour: Palette.tech,
    ),
    FundLine.sales: (
      name: 'ЗБУТ',
      note: 'кредити з продажу і запитів',
      colour: Palette.gold,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final face = _faces[line]!;
    final level = sim.fundingOf(line).value;
    final mult = 1 + PrototypeSimulation.fundStepPerLevel * level;
    return HudBox(
      cut: 9,
      fill: Palette.shell.withValues(alpha: 0.6),
      edge: level > 0 ? face.colour.withValues(alpha: 0.5) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(11, 8, 8, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  face.name,
                  style: AppText.body(
                    9,
                    weight: FontWeight.w800,
                    color: face.colour,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  face.note,
                  style: AppText.body(9, color: Palette.textFaint),
                ),
              ],
            ),
          ),
          Text(
            '×${mult.toStringAsFixed(2)}',
            style: AppText.display(
              14,
              weight: FontWeight.w700,
              color: level > 0 ? face.colour : Palette.textDim,
            ),
          ),
          const SizedBox(width: 10),
          HudButton(
            onTap: free > 0 ? () => onInvest(line) : null,
            label: '+1 ТРАНШ',
            accent: face.colour,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
          ),
        ],
      ),
    );
  }
}
