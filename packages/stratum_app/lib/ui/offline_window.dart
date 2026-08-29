import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'game_modal.dart';
import 'hud.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// What the absence earned, said once on the way back in.
///
/// Only shown for absences long enough to be an event; short gaps settle
/// silently before this widget is ever built. The income is already in the
/// store by now -- the window reports, it does not hold the payout hostage.
class OfflineWindow extends StatelessWidget {
  const OfflineWindow({
    required this.gain,
    required this.away,
    required this.onClose,
    super.key,
  });

  final OfflineGain gain;
  final Duration away;
  final VoidCallback onClose;

  static String _span(Duration span) {
    if (span.inHours > 0) {
      return '${span.inHours} год ${span.inMinutes % 60} хв';
    }
    if (span.inMinutes > 0) return '${span.inMinutes} хв';
    return '${span.inSeconds} с';
  }

  @override
  Widget build(BuildContext context) {
    return GameModal(
      leading: const Icon(Ti.moon, size: 16, color: Palette.tech),
      title: 'ОФЛАЙН ДОХІД',
      inset: 46,
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 8),
            child: Text(
              'вас не було ${_span(away)} · ${gain.cycles} циклів на '
              '${(gain.efficiency * 100).round()}% темпу',
              style: AppText.body(9.5, color: Palette.textMuted),
            ),
          ),
          for (final entry in gain.gained.entries)
            _GainRow(id: entry.key, value: entry.value),
          const SizedBox(height: 12),
          HudButton(
            onTap: onClose,
            label: 'ЗАБРАТИ',
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ],
      ),
    );
  }
}

class _GainRow extends StatelessWidget {
  const _GainRow({required this.id, required this.value});

  final ResourceId id;
  final BigDouble value;

  @override
  Widget build(BuildContext context) {
    if (value.isZero) return const SizedBox.shrink();
    final style = resourceStyles[id]!;
    final colour = style.colour;
    final label = style.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ResourceIcon(id, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppText.body(11, color: Palette.textMuted),
            ),
          ),
          Text(
            '+$value',
            style: AppText.display(14, weight: FontWeight.w700, color: colour),
          ),
        ],
      ),
    );
  }
}
