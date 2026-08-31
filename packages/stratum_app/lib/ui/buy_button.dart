import 'package:flutter/widgets.dart';

import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'resource_icon.dart';
import 'tokens.dart';

/// The price on any upgrade button: the credits coin beside the cost, gold
/// while the wallet can pay, faint while it cannot. Upgrades are paid in
/// credits (2026-08-30), so the button wears the currency's own face.
class BuyButton extends StatelessWidget {
  const BuyButton({
    required this.cost,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudButton(
      onTap: enabled ? onTap : null,
      holdRepeat: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ResourceIcon(
            ResourceId.credits,
            size: 12,
            colour: enabled ? null : Palette.textFaint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              cost,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                11.5,
                weight: FontWeight.w700,
                color: enabled ? Palette.gold : Palette.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
