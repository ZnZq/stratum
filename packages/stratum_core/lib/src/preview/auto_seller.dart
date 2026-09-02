import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'automations.dart';
import 'trade_desk.dart';

/// One position's auto-sale settings: whether it sells on its own, how
/// often, and the floor it never sells below. The SHARE sold is the
/// position's own sell share -- the same notch the manual button uses,
/// so the two never disagree.
class AutoSellRule {
  AutoSellRule(ResourceId id)
    : enabled = Signal(false, name: 'auto sell ${id.name}'),
      intervalSeconds = Signal(60, name: 'auto sell ${id.name} interval'),
      keep = Signal(BigDouble.zero, name: 'auto sell ${id.name} keep');

  final Signal<bool> enabled;
  final Signal<double> intervalSeconds;

  /// Not sold while the pile is under this.
  final Signal<BigDouble> keep;

  double bank = 0;

  Map<String, Object?> toJson() => {
    if (enabled.value) 'on': true,
    if (intervalSeconds.value != 60) 'iv': intervalSeconds.value,
    if (!keep.value.isZero) 'keep': keep.value.toJson(),
  };

  void readJson(Object? json) {
    enabled.value = json is Map && json['on'] == true;
    final iv = json is Map ? json['iv'] : null;
    intervalSeconds.value = iv is num && iv > 0 ? iv.toDouble() : 60;
    final held = json is Map ? json['keep'] : null;
    keep.value = held is String
        ? (BigDouble.tryParse(held) ?? BigDouble.zero)
        : BigDouble.zero;
    bank = 0;
  }
}

/// Auto-sell: every enabled position sells its share on its own
/// interval, as long as the pile stays above the kept floor. ONLINE
/// ONLY: an absence sells nothing, the intervals restart on return.
class AutoSeller {
  AutoSeller(this._stock, this._desk);

  final Stockpile _stock;
  final TradeDesk _desk;

  /// Whether the whole thing runs; each position has its own switch too.
  final Signal<bool> enabled = Signal(true, name: 'auto sell on');

  final Map<ResourceId, AutoSellRule> rules = {
    for (final row in TradeDesk.priceTable) row.id: AutoSellRule(row.id),
  };

  AutoSellRule ruleOf(ResourceId id) => rules[id]!;

  /// Walks [span] seconds: a position whose interval fell due sells once
  /// per due cycle, capped so a stall never comes back as a fire sale.
  /// Returns the credits paid.
  BigDouble run(double span) {
    if (!enabled.value || span <= 0) return BigDouble.zero;
    var paid = BigDouble.zero;
    for (final entry in rules.entries) {
      final rule = entry.value;
      if (!rule.enabled.value) continue;
      rule.bank += span / rule.intervalSeconds.value;
      var cycles = rule.bank.floor();
      if (cycles > 3) cycles = 3;
      rule.bank -= rule.bank.floor();
      for (var i = 0; i < cycles; i++) {
        if (!_stock.amount(entry.key).gteWithTolerance(rule.keep.value)) break;
        paid += _desk.sellPosition(entry.key);
      }
    }
    return paid;
  }

  void restamp() {
    for (final rule in rules.values) {
      rule.bank = 0;
    }
  }

  Map<String, Object?> toJson() => {
    if (!enabled.value) 'off': true,
    for (final entry in rules.entries)
      if (entry.value.toJson().isNotEmpty) entry.key.name: entry.value.toJson(),
  };

  void readJson(Object? json) {
    enabled.value = !(json is Map && json['off'] == true);
    for (final entry in rules.entries) {
      entry.value.readJson(json is Map ? json[entry.key.name] : null);
    }
  }
}

/// The interval presets the sell rules offer.
List<double> get autoSellIntervals => automationIntervals;
