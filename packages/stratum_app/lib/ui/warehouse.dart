import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'game_modal.dart';
import 'resource_plate.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// Everything the player owns, on shelves.
///
/// Opens over whatever screen is showing rather than taking a tab of its own:
/// the resource strip at the top is already the short version of this, so
/// pulling it open is the gesture, and the navigation stays five wide.
class WarehouseSheet extends StatelessWidget {
  const WarehouseSheet({required this.game, required this.onClose, super.key});

  final Game game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GameModal(
      leading: const Icon(Ti.buildingWarehouse, size: 16, color: Palette.tech),
      title: 'СКЛАД',
      anchor: ModalAnchor.stretch,
      contentPadding: EdgeInsets.zero,
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          for (final shelf in ResourceShelf.values)
            _Shelf(
              shelf: shelf,
              game: game,
              first: shelf == ResourceShelf.values.first,
            ),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelf, required this.game, this.first = false});

  final ResourceShelf shelf;
  final Game game;

  /// The first shelf sits straight under the title bar, so it does not want
  /// the gap that separates one shelf from the last.
  final bool first;

  static const double _gap = 8;

  /// Why a lane is empty, when the reason is depth rather than luck.
  ///
  /// The only thing said beside a name here. What a shelf holds is a total,
  /// and a total needs no qualifier; the rate it grows at belongs where the
  /// player is watching it grow, not where they are counting it.
  String? _hint(ResourceId id) {
    if (id case ResourceId.cuprite || ResourceId.ferrite || ResourceId.silicite
        when !game.sim.oreUnlocked(id)) {
      return 'глибше';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: first ? 2 : 14, bottom: 7),
          child: Stat(label: shelf.label, rule: true),
        ),
        // The same plates the mine lays its loot table out with. What a
        // strike can bring up and what the strikes have brought up are the
        // same object seen twice, so they are read the same way -- and two
        // to a row fits a shelf on screen instead of a scroll of rows.
        LayoutBuilder(
          builder: (context, constraints) {
            final half = (constraints.maxWidth - _gap) / 2;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final id in resourcesOn(shelf))
                  ResourcePlate(
                    id: id,
                    amount: '${game.sim.stock.amount(id)}',
                    aside: _hint(id),
                    width: half,
                    dim: game.sim.stock.amount(id).isZero,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
