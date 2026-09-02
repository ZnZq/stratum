import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../resource_plate.dart';
import '../tokens.dart';

/// The grab bar that folds the upgrades away.
///
/// Collapsed, the deck keeps only what the player watches while drilling --
/// hardness, power, cycles left -- and hands the rest of the screen back to
/// the rock.
/// What a strike can bring up: a grid of plates, two to a row.
///
/// Regolith heads it on a row of its own -- the one certain lane, quoting a
/// band rather than a figure. Under it the chances: the ore ladder, crystals,
/// and the two exotic lanes paired at the foot. Ores still locked by depth
/// stay listed and dimmed, so the grid doubles as the map of what going
/// deeper opens.
class LootTable extends StatelessWidget {
  const LootTable({required this.sim, super.key});

  final PrototypeSimulation sim;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final layer = sim.layer.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'ЗДОБИЧ ЗА УДАР',
          style: AppText.body(
            8,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final half = (constraints.maxWidth - _gap) / 2;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                // Regolith takes the whole row: it is the one lane that is
                // certain, and it quotes a band rather than a figure, which
                // needs the width.
                ResourcePlate(
                  id: ResourceId.regolith,
                  amount:
                      '${sim.strikeRegolithBand.min}'
                      ' – ${sim.strikeRegolithBand.max}',
                  width: constraints.maxWidth,
                  shadows: true,
                ),
                for (final row in PrototypeSimulation.oreTable)
                  if (layer >= row.unlockAt)
                    ResourcePlate(
                      id: row.id,
                      aside: '${(row.chance * 100).round()}%',
                      amount:
                          '${PrototypeSimulation.oreDropAt(layer) * sim.fundScaleOf(row.id)}',
                      width: half,
                      shadows: true,
                    )
                  else
                    ResourcePlate(
                      id: row.id,
                      amount: 'з ${row.unlockAt} м',
                      width: half,
                      dim: true,
                      shadows: true,
                    ),
                ResourcePlate(
                  id: ResourceId.crystals,
                  aside: '${(sim.crystalChance * 100).round()}%',
                  amount: '${PrototypeSimulation.crystalDropAt(layer)}',
                  width: half,
                  shadows: true,
                ),
                // The two exotic lanes close the table side by side: same
                // odds, both outside the ore ladder, and both worth nothing
                // to the rig -- one is the anti-brick drip, the other the
                // simulation's own substrate.
                ResourcePlate(
                  id: ResourceId.quantonium,
                  aside:
                      '${(PrototypeSimulation.strikeQuantoniumChance * 100).toStringAsFixed(0)}%',
                  amount: '${PrototypeSimulation.quantoniumDropAt(layer)}',
                  width: half,
                  shadows: true,
                ),
                ResourcePlate(
                  id: ResourceId.rawData,
                  aside:
                      '${(PrototypeSimulation.rawDataChance * 100).toStringAsFixed(0)}%',
                  amount:
                      '${PrototypeSimulation.rawDataDropAt(layer) * sim.fundScaleOf(ResourceId.rawData)}',
                  width: half,
                  shadows: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
