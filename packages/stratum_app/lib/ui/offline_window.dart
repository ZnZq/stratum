import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xB3070A10),
        child: Center(
          child: Container(
            width: 270,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Palette.bar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x407FD9C4)),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 26),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Ti.moon, size: 22, color: Palette.tech),
                const SizedBox(height: 10),
                Text(
                  'ОФЛАЙН ДОХІД',
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    12,
                    weight: FontWeight.w800,
                    color: Palette.text,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'вас не було ${_span(away)} · ${gain.cycles} циклів на '
                  '${(gain.efficiency * 100).round()}% темпу',
                  textAlign: TextAlign.center,
                  style: AppText.body(9.5, color: Palette.textMuted),
                ),
                const SizedBox(height: 14),
                for (final entry in gain.gained.entries)
                  _GainRow(id: entry.key, value: entry.value),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Palette.goldWell,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Palette.amber),
                    ),
                    child: Text(
                      'ЗАБРАТИ',
                      style: AppText.body(
                        11,
                        weight: FontWeight.w800,
                        color: Palette.gold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
