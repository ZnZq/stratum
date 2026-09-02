import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'trade_desk.dart';
import 'trade_request.dart';

/// Auto-requests: fulfils a request on the board when it respects two
/// rules the player sets -- none of its lines asks for a PROTECTED
/// resource, and no line asks for more than [maxShare] of what the
/// pile holds. ONLINE ONLY.
class AutoFulfil {
  AutoFulfil(this._stock, this._desk);

  final Stockpile _stock;
  final TradeDesk _desk;

  /// The shares the picker offers. PROVISIONAL.
  static const List<double> shares = [0.25, 0.5, 0.75, 1.0];

  final Signal<bool> enabled = Signal(true, name: 'auto fulfil on');

  /// Resources a request may not take at all.
  final Signal<Set<ResourceId>> blocked = Signal(
    const {},
    name: 'auto fulfil blocked',
  );

  /// The largest share of a pile one request line may ask for.
  final Signal<double> maxShare = Signal(0.5, name: 'auto fulfil max share');

  bool isBlocked(ResourceId id) => blocked.value.contains(id);

  void setBlocked(ResourceId id, bool value) {
    final next = Set<ResourceId>.of(blocked.value);
    if (value) {
      next.add(id);
    } else {
      next.remove(id);
    }
    blocked.value = next;
  }

  /// Whether [request] passes the player's rules and the desk's own.
  bool accepts(TradeRequest request) {
    if (!_desk.canFulfil(request)) return false;
    for (final need in request.needs) {
      if (isBlocked(need.id)) return false;
      final held = _stock.amount(need.id);
      if (need.amount > held * BigDouble.fromNum(maxShare.value)) return false;
    }
    return true;
  }

  /// Fulfils every acceptable request on the board. Returns the credits
  /// paid.
  BigDouble run() {
    if (!enabled.value) return BigDouble.zero;
    var paid = BigDouble.zero;
    for (final request in List<TradeRequest>.of(_desk.requests)) {
      if (!accepts(request)) continue;
      final payout = _desk.requestPayout(request);
      if (_desk.fulfilRequest(request)) paid += payout;
    }
    return paid;
  }

  Map<String, Object?> toJson() => {
    if (!enabled.value) 'off': true,
    if (maxShare.value != 0.5) 'max': maxShare.value,
    if (blocked.value.isNotEmpty)
      'block': [for (final id in blocked.value) id.name],
  };

  void readJson(Object? json) {
    enabled.value = !(json is Map && json['off'] == true);
    final max = json is Map ? json['max'] : null;
    maxShare.value = max is num && max > 0
        ? max.toDouble().clamp(0.0, 1.0)
        : 0.5;
    final block = json is Map ? json['block'] : null;
    blocked.value = {
      if (block is List)
        for (final id in ResourceId.values)
          if (block.contains(id.name)) id,
    };
  }
}
