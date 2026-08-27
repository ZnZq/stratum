import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../game.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// Transient reports -- resources coming in, a save that landed, a load that
/// failed -- flush against the left edge, vertically centred, gone seconds
/// after their last update.
///
/// Never interactive: the layer ignores pointers, so a card can overlap a
/// control without stealing a tap from it.
class NoticeLayer extends StatelessWidget {
  const NoticeLayer({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      // Anchored to the quiet band of the scene: below the depth readout,
      // stacking downward over the rock, so a full column of cards ends well
      // before the deck's readouts begin. Centring put them exactly where
      // the deck panel lives.
      top: AppMetrics.resourceBar + 112,
      bottom: AppMetrics.navTotal,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final notice in game.notices)
                _NoticeCard(key: ValueKey(notice.id), notice: notice),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, super.key});

  final Notice notice;

  (IconData, Color) get _face {
    if (notice.kind == NoticeKind.gain) {
      final style = resourceStyles[notice.resource]!;
      return (style.icon, style.colour);
    }
    return switch (notice.kind) {
      NoticeKind.success => (Ti.check, Palette.tech),
      NoticeKind.error => (Ti.alertTriangle, Palette.quantonium),
      _ => (Ti.deviceFloppy, Palette.textMuted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = _face;
    return AnimatedOpacity(
      opacity: notice.leaving ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Transform.translate(
          offset: Offset((t - 1) * 34, 0),
          child: Opacity(opacity: t, child: child),
        ),
        // Flush with the edge it slides out of: square on the left, rounded
        // where it meets the scene.
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
          decoration: BoxDecoration(
            // The plate alone is translucent, not the card: the rock keeps
            // showing through while the figures stay at full strength.
            color: const Color(0xD11E2834),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(color: colour.withValues(alpha: 0.4)),
              right: BorderSide(color: colour.withValues(alpha: 0.4)),
              bottom: BorderSide(color: colour.withValues(alpha: 0.4)),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x59000000), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice.kind == NoticeKind.gain)
                ResourceIcon(notice.resource!, size: 19)
              else
                Icon(icon, size: 13, color: colour),
              const SizedBox(width: 6),
              if (notice.text.contains('\n'))
                // A gain card: the streak loud, the stockpile total
                // under it in a smaller, quieter line. Tight line
                // heights keep the two rows barely taller than one.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Only the streak reacts to a refresh: a brief
                    // swell of the glyphs and back. Transform.scale is
                    // paint only, so neither the card nor the total
                    // line under it moves.
                    TweenAnimationBuilder<double>(
                      key: ValueKey(notice.revision),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 170),
                      builder: (context, t, child) => Transform.scale(
                        scale: 1 + 0.15 * math.sin(math.pi * t),
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                      child: Text(
                        notice.text.split('\n').first,
                        style: AppText.display(
                          10,
                          weight: FontWeight.w700,
                          color: colour,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      notice.text.split('\n').last,
                      style: AppText.display(
                        7,
                        color: Palette.textMuted,
                        height: 1,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  notice.text,
                  style: AppText.display(
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
