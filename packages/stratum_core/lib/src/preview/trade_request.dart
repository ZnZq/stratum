import '../big_double.dart';
import '../stockpile.dart';

/// One buyer's order: hand over the listed amounts, get paid over list price.
///
/// A plain object rather than signals: a request never changes after it is
/// posted -- it is fulfilled or it expires -- and the list it lives in is
/// redrawn by the clock that expires it.
class TradeRequest {
  TradeRequest({
    required this.needs,
    required this.premium,
    required this.expiresAtMs,
  });

  final List<({ResourceId id, BigDouble amount})> needs;

  /// Paid on top of list price, as a fraction (0.24 reads "премія +24%").
  final double premium;

  /// Wall-clock, like the drift: a courier does not pause with the engines.
  final int expiresAtMs;

  Map<String, Object?> toJson() => {
    'premium': premium,
    'expires': expiresAtMs,
    'needs': {for (final need in needs) need.id.name: need.amount.toJson()},
  };

  static TradeRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final needs = <({ResourceId id, BigDouble amount})>[];
    final raw = json['needs'];
    if (raw is Map) {
      for (final id in ResourceId.values) {
        final amount = raw[id.name];
        final parsed = amount is String ? BigDouble.tryParse(amount) : null;
        if (parsed != null) needs.add((id: id, amount: parsed));
      }
    }
    if (needs.isEmpty) return null;
    final premium = json['premium'];
    final expires = json['expires'];
    return TradeRequest(
      needs: needs,
      premium: premium is num ? premium.toDouble() : 0.2,
      expiresAtMs: expires is int ? expires : 0,
    );
  }
}
