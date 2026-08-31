import 'package:flutter/widgets.dart';

import '../game.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'tokens.dart';
import 'warehouse.dart';

/// The warehouse as a modal, for screens where checking stock must not
/// cost a navigation. Same shelves as the tab -- one room, two doors, and
/// the room is the same widget so the doors cannot drift apart.
class WarehouseSheet extends StatelessWidget {
  const WarehouseSheet({required this.game, required this.onClose, super.key});

  final Game game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return HudModal(
      icon: Ic.warehouse,
      title: 'СКЛАД',
      accent: Palette.tech,
      anchor: ModalAnchor.fill,
      onClose: onClose,
      contentPadding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
      child: WarehouseScreen(game: game),
    );
  }
}
