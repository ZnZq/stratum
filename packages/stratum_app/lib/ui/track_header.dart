import 'package:flutter/widgets.dart';

import 'batch_picker.dart';
import 'tokens.dart';

/// The heading over a list of upgrade tracks: the section's name and the
/// batch picker that every row below obeys.
class TrackHeader extends StatelessWidget {
  const TrackHeader({
    required this.label,
    required this.batch,
    required this.onPick,
    super.key,
  });

  final String label;
  final int batch;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.body(
              8.5,
              weight: FontWeight.w700,
              color: Palette.tech,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          BatchPicker(batch: batch, onPick: onPick),
        ],
      ),
    );
  }
}
