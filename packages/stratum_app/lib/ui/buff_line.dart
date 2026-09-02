import 'package:flutter/widgets.dart';

import 'arm_style.dart';
import 'hud.dart';
import 'tokens.dart';

/// One buff named with its per-level step: what the evolution overlay and
/// the part sheet both list, one under the other.
class BuffLine extends StatelessWidget {
  const BuffLine({
    required this.buff,
    required this.stepColour,
    this.total,
    this.ruled = true,
    super.key,
  });

  final ArmBuff buff;
  final Color stepColour;

  /// The standing total at the far end, where a sheet has one to show.
  final String? total;

  /// Whether the line sits on a hairline rule (the sheet) or floats free
  /// (the overlay).
  final bool ruled;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(buff.label, style: AppText.body(10, color: Palette.textDim)),
        const SizedBox(width: 6),
        Text(buff.step, style: AppText.display(9.5, color: stepColour)),
        if (total != null) ...[
          const Spacer(),
          Text(
            total!,
            style: AppText.display(
              10.5,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
        ],
      ],
    );
    const margin = EdgeInsets.only(bottom: 2);
    return ruled
        ? HudRow(margin: margin, child: row)
        : Padding(padding: margin, child: row);
  }
}
