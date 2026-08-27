import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
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
    final sim = game.sim;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0xB3070A10)),
          ),
        ),
        Positioned(
          top: AppMetrics.resourceBar - 8,
          left: 10,
          right: 10,
          bottom: AppMetrics.navTotal + 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.bar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x407FD9C4)),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 26),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: onClose),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    children: [
                      for (final shelf in ResourceShelf.values)
                        _Shelf(shelf: shelf, game: game),
                    ],
                  ),
                ),
                _Footer(sim: sim),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
      child: Row(
        children: [
          const Icon(Ti.buildingWarehouse, size: 17, color: Palette.tech),
          const SizedBox(width: 8),
          Text(
            'СКЛАД',
            style: AppText.body(
              12,
              weight: FontWeight.w800,
              color: Palette.text,
              letterSpacing: 2.4,
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Ti.close, size: 16, color: Palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelf, required this.game});

  final ResourceShelf shelf;
  final Game game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Text(
                shelf.label.toUpperCase(),
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.tech,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x267FD9C4)),
                  child: SizedBox(height: 1),
                ),
              ),
            ],
          ),
        ),
        for (final id in resourcesOn(shelf)) _Row(id: id, game: game),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.id, required this.game});

  final ResourceId id;
  final Game game;

  /// The average income of this resource, in its own terms.
  ///
  /// A rate per second rather than per cycle: both lanes throw the same
  /// strike at different cadences, so seconds are the only unit that can hold
  /// the hand and the rig in one number. Lanes that pay on events instead of
  /// on strikes have no rate to quote and say nothing.
  String? get _income {
    final sim = game.sim;
    if (id case ResourceId.cuprite || ResourceId.ferrite || ResourceId.silicite
        when !sim.oreUnlocked(id)) {
      return 'глибше';
    }
    final rate = game.yieldPerSecond(id);
    return rate.isZero ? null : '$rate / с';
  }

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    final held = game.sim.stock.amount(id);
    final empty = held.isZero;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Opacity(
        opacity: empty ? 0.45 : 1,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.well,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Palette.lineBar),
              ),
              child: ResourceIcon(id, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    style.label,
                    style: AppText.body(
                      12.5,
                      weight: FontWeight.w700,
                      color: Palette.text,
                    ),
                  ),
                  Text(
                    style.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(9.5, color: Palette.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$held',
                  style: AppText.display(
                    15,
                    weight: FontWeight.w700,
                    color: empty ? Palette.textFaint : style.colour,
                  ),
                ),
                if (_income case final income?)
                  Text(
                    income,
                    style: AppText.display(9.5, color: Palette.textFaint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The store has no cap, and saying so is worth a line: an idle player's first
/// question about a warehouse is what happens when it fills.
class _Footer extends StatelessWidget {
  const _Footer({required this.sim});

  final PrototypeSimulation sim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.lineBar)),
      ),
      child: Row(
        children: [
          Text(
            'склад безмежний · капів немає',
            style: AppText.body(9.5, color: Palette.textFaint),
          ),
          const Spacer(),
          Text(
            'глибина ${sim.layer.value + 1} м',
            style: AppText.display(10.5, color: Palette.textMuted),
          ),
        ],
      ),
    );
  }
}
