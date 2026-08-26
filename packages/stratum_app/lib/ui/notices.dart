import 'package:flutter/widgets.dart';

import '../game.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// Transient reports -- a save that landed, a load that failed -- stacked
/// under the resource strip and gone in seconds.
///
/// Never interactive: the layer ignores pointers, so a card can overlap a
/// control without stealing a tap from it.
class NoticeLayer extends StatelessWidget {
  const NoticeLayer({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppMetrics.resourceBar + 6,
      right: 10,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final notice in game.notices)
              _NoticeCard(key: ValueKey(notice.id), notice: notice),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, super.key});

  final Notice notice;

  (IconData, Color) get _face => switch (notice.kind) {
    NoticeKind.success => (Ti.check, Palette.tech),
    NoticeKind.error => (Ti.alertTriangle, Palette.quantonium),
    NoticeKind.info => (Ti.deviceFloppy, Palette.textMuted),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = _face;
    return AnimatedOpacity(
      opacity: notice.leaving ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Transform.translate(
          offset: Offset((1 - t) * 46, 0),
          child: Opacity(opacity: t, child: child),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          decoration: BoxDecoration(
            color: Palette.bar,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: colour.withValues(alpha: 0.45)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colour),
              const SizedBox(width: 7),
              Text(
                notice.text,
                style: AppText.body(
                  10.5,
                  weight: FontWeight.w600,
                  color: Palette.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
