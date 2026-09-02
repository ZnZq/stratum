import 'package:flutter/widgets.dart';

import 'buy_button.dart';
import 'hud.dart';
import 'tokens.dart';

/// The header of an upgrade track, as the arm's parts and the drill's
/// tracks both draw it: a face, the name with something beside it, the
/// level at the far end, one line of detail underneath, and the buy slot
/// at a fixed width so the row never twitches when a price grows a digit.
class UpgradeRow extends StatelessWidget {
  const UpgradeRow({
    required this.leading,
    required this.title,
    required this.beside,
    required this.besideGap,
    required this.level,
    required this.levelLit,
    required this.detail,
    required this.detailGap,
    required this.capped,
    required this.cost,
    required this.enabled,
    required this.onBuy,
    super.key,
  });

  final Widget leading;
  final String title;

  /// What sits after the name on its line: a mark tag, a note.
  final Widget beside;
  final double besideGap;
  final int level;
  final bool levelLit;

  /// The line under the title: a generation track, an effect readout.
  final Widget detail;
  final double detailGap;

  /// A track at its ceiling shows the ceiling instead of a price.
  final bool capped;
  final String cost;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppText.body(
                      8.5,
                      weight: FontWeight.w700,
                      color: Palette.tech,
                      letterSpacing: 1.6,
                    ),
                  ),
                  SizedBox(width: besideGap),
                  beside,
                  const Spacer(),
                  Text(
                    '$level',
                    style: AppText.display(
                      9.5,
                      weight: FontWeight.w600,
                      color: levelLit ? Palette.gold : Palette.textFaint,
                    ),
                  ),
                ],
              ),
              SizedBox(height: detailGap),
              detail,
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 104,
          child: capped
              ? const HudButton(
                  onTap: null,
                  label: 'межа',
                  padding: EdgeInsets.symmetric(vertical: 8),
                )
              : BuyButton(cost: cost, enabled: enabled, onTap: onBuy),
        ),
      ],
    );
  }
}
