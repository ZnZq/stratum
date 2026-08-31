import 'dart:async';

import 'package:stratum_core/stratum_core.dart';

/// A transient report: something happened, said once, gone in seconds.
enum NoticeKind { success, error, info, gain }

class Notice {
  Notice({
    required this.id,
    required this.text,
    required this.kind,
    this.key,
    this.resource,
  });

  final int id;

  /// Mutable on purpose: a keyed notice is updated in place while its kin
  /// keep arriving, instead of stacking a card per event.
  String text;

  final NoticeKind kind;

  /// Coalescing identity: a new report with the same key refreshes this card
  /// and its lifetime rather than adding another.
  final String? key;

  /// For [NoticeKind.gain]: which resource the card is about.
  final ResourceId? resource;

  /// Bumped on every in-place refresh, so the card can visibly flinch when
  /// its number moves without growing a new card.
  int revision = 0;

  /// Set shortly before removal, so the card can fade instead of popping.
  bool leaving = false;

  Timer? life;
}
