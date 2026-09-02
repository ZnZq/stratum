import '../reactive_graph.dart';

/// One upgrade track the buyer may work: its key (what the save and the
/// screen call it), whether a level can be bought right now, and the
/// act of buying one.
class AutoBuyTarget {
  const AutoBuyTarget({
    required this.key,
    required this.canBuy,
    required this.buy,
  });

  final String key;
  final bool Function() canBuy;
  final bool Function() buy;
}

/// Auto-buy: every [intervalSeconds] buys up to [perCycle] levels across
/// the tracks the player switched on, one level per track in turn so no
/// single track hogs the purse. ONLINE ONLY: purchases are decisions,
/// and an absence makes none.
class AutoBuyer {
  AutoBuyer(this.targets);

  /// Every track that CAN be automated; which ones are is [chosen].
  final List<AutoBuyTarget> targets;

  /// How many purchases one cycle may make. PROVISIONAL.
  static const List<int> perCycleOptions = [1, 3, 5, 10];

  final Signal<bool> enabled = Signal(true, name: 'auto buy on');
  final Signal<double> intervalSeconds = Signal(30, name: 'auto buy interval');
  final Signal<int> perCycle = Signal(1, name: 'auto buy per cycle');

  /// The keys of the tracks switched on.
  final Signal<Set<String>> chosen = Signal(const {}, name: 'auto buy chosen');

  bool isChosen(String key) => chosen.value.contains(key);

  void setChosen(String key, bool value) {
    final next = Set<String>.of(chosen.value);
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    chosen.value = next;
  }

  double _bank = 0;

  /// Walks [span] seconds of cycles and returns how many levels landed.
  int run(double span) {
    if (!enabled.value || span <= 0 || chosen.value.isEmpty) return 0;
    _bank += span / intervalSeconds.value;
    var cycles = _bank.floor();
    if (cycles > 3) cycles = 3;
    _bank -= _bank.floor();
    var bought = 0;
    for (var cycle = 0; cycle < cycles; cycle++) {
      bought += _runCycle();
    }
    return bought;
  }

  int _runCycle() {
    final active = [
      for (final target in targets)
        if (chosen.value.contains(target.key)) target,
    ];
    var bought = 0;
    var progress = true;
    // Round-robin: one level per track per pass, until the cycle's
    // allowance is spent or nothing affordable is left.
    while (bought < perCycle.value && progress) {
      progress = false;
      for (final target in active) {
        if (bought >= perCycle.value) break;
        if (!target.canBuy()) continue;
        if (target.buy()) {
          bought++;
          progress = true;
        }
      }
    }
    return bought;
  }

  void restamp() => _bank = 0;

  Map<String, Object?> toJson() => {
    if (!enabled.value) 'off': true,
    if (intervalSeconds.value != 30) 'iv': intervalSeconds.value,
    if (perCycle.value != 1) 'n': perCycle.value,
    if (chosen.value.isNotEmpty) 't': [...chosen.value],
  };

  void readJson(Object? json) {
    enabled.value = !(json is Map && json['off'] == true);
    final iv = json is Map ? json['iv'] : null;
    intervalSeconds.value = iv is num && iv > 0 ? iv.toDouble() : 30;
    final n = json is Map ? json['n'] : null;
    perCycle.value = n is num && n >= 1 ? n.toInt() : 1;
    final t = json is Map ? json['t'] : null;
    chosen.value = {
      if (t is List)
        for (final key in t)
          if (key is String && targets.any((target) => target.key == key)) key,
    };
    _bank = 0;
  }
}
