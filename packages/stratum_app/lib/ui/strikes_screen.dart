import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'tabler_icons.dart';
import 'tokens.dart';
import 'upgrades_screen.dart';

/// The manual lane: what a blow is worth, and the levers that grow it.
///
/// Its own screen beside «Бури» because the two lanes are two different
/// investments: the drills work while the player is away, the strikes only
/// pay while a finger is on the rock.
class StrikesScreen extends StatelessWidget {
  const StrikesScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;

    return ColoredBox(
      color: Palette.scene,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            decoration: BoxDecoration(
              color: Palette.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.lineBar),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'СИЛА УДАРУ',
                  style: AppText.body(
                    8.5,
                    weight: FontWeight.w700,
                    color: Palette.tech,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${sim.strikePower}',
                  style: AppText.display(
                    26,
                    weight: FontWeight.w700,
                    color: Palette.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 енергія за удар · енергія '
                  '${sim.energy.value} / ${sim.energyCap} · '
                  '+${sim.energyPerRegen}/${Game.energyInterval}',
                  style: AppText.display(11.5, color: Palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ПРОКАЧКА УДАРІВ',
            style: AppText.body(
              8.5,
              weight: FontWeight.w700,
              color: Palette.tech,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          UpgradeRow(
            label: 'сила удару',
            value: '${sim.strikePower}',
            note: 'рівень ${sim.strikeLevel.value}',
            preview:
                '${sim.strikePower} → '
                '${sim.strikePowerAt(sim.strikeLevel.value + 1)}',
            cost: '${sim.strikeUpgradeCost}',
            affordable: sim.canBuyStrikeUpgrade,
            onBuy: game.buyStrikeUpgrade,
          ),
          const SizedBox(height: 9),
          UpgradeRow(
            label: 'ємність енергії',
            value: '${sim.energyCap}',
            note: 'рівень ${sim.energyCapLevel.value}',
            preview:
                '${sim.energyCap} → '
                '${sim.energyCap + PrototypeSimulation.energyPerCapLevel}',
            cost: '${sim.energyCapUpgradeCost}',
            affordable: sim.canBuyEnergyCapUpgrade,
            onBuy: game.buyEnergyCapUpgrade,
          ),
          const SizedBox(height: 9),
          UpgradeRow(
            label: 'відновлення',
            value: '+${sim.energyPerRegen}',
            note: 'рівень ${sim.energyRegenLevel.value}',
            preview:
                '+${sim.energyPerRegen} → +${sim.energyPerRegen + 1} '
                'за ${Game.energyInterval}',
            cost: '${sim.energyRegenUpgradeCost}',
            affordable: sim.canBuyEnergyRegenUpgrade,
            onBuy: game.buyEnergyRegenUpgrade,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Ti.handClick, size: 13, color: Palette.textFaint),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'удар бʼє на ${_sharePercent(sim)}% сили рига '
                  'і добуває відповідну частку циклу',
                  style: AppText.body(9.5, color: Palette.textFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _sharePercent(PrototypeSimulation sim) {
    final ratio = (sim.strikePower / sim.power.value).toDouble() * 100;
    return ratio.toStringAsFixed(0);
  }
}
