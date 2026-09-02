import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'craft_line_card.dart';
import 'craft_recipe_sheet.dart';
import 'craft_resource_strip.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'tokens.dart';
import 'warehouse_sheet.dart';

/// The bench: every crafting line, the till at the top, the next machine at
/// the bottom. The lines convert on wall time -- the screen's own second
/// timer keeps them settling while the player watches.
class CraftScreen extends StatefulWidget {
  const CraftScreen({required this.game, super.key});

  final Game game;

  @override
  State<CraftScreen> createState() => _CraftScreenState();
}

class _CraftScreenState extends State<CraftScreen> {
  Timer? _timer;

  /// Which line's picker is open; null = none. -2 opens the warehouse.
  int? _sheetLine;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sync());
    // Settle without poking: the first build is already about to read the
    // fresh state, and a notify during build is an assertion.
    widget.game.sim.syncCraft(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    widget.game.sim.syncCraft(DateTime.now().millisecondsSinceEpoch);
    // The second-by-second settle is this screen's own news: rebuild it,
    // not the whole shell. Stock that moved reaches every other reader
    // through the stockpile watch.
    if (mounted) setState(() {});
  }

  void _poke(VoidCallback act) {
    act();
    widget.game.pokeListeners();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final sim = game.sim;
    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: [
            CraftResourceStrip(
              game: game,
              onWarehouse: () => setState(() => _sheetLine = -2),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < sim.craftLines.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              CraftLineCard(
                game: game,
                index: i,
                onPickRecipe: () => setState(() => _sheetLine = i),
                onChange: _poke,
              ),
            ],
            const SizedBox(height: 10),
            HudButton(
              onTap: sim.canBuyCraftLine
                  ? () => _poke(() => sim.buyCraftLine())
                  : null,
              holdRepeat: true,
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'НОВА ЛІНІЯ · ',
                      style: AppText.body(
                        9.5,
                        weight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: sim.canBuyCraftLine
                            ? Palette.gold
                            : Palette.textFaint,
                      ),
                    ),
                    Text(
                      '${sim.craftLineCost}',
                      style: AppText.display(
                        11,
                        weight: FontWeight.w700,
                        color: sim.canBuyCraftLine
                            ? Palette.gold
                            : Palette.textFaint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ResourceIcon(
                      ResourceId.credits,
                      size: 10,
                      colour: sim.canBuyCraftLine ? null : Palette.textFaint,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_sheetLine == -2)
          Positioned.fill(
            child: WarehouseSheet(
              game: game,
              onClose: () => setState(() => _sheetLine = null),
            ),
          )
        else if (_sheetLine != null)
          Positioned.fill(
            child: CraftRecipeSheet(
              game: game,
              index: _sheetLine!,
              onClose: () => setState(() => _sheetLine = null),
              onChange: _poke,
            ),
          ),
      ],
    );
  }
}
