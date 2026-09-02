import '../big_double.dart';
import '../random_source.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'trade_groups.dart';
import 'trade_request.dart';

/// The trade hall: the fixed price list, the per-position and per-shelf
/// sell switches, and the request board. Sales pay through [earn] so the
/// financing ladder sees every credit; prices wear [scaleOf], the credits
/// lane's multiplier.
class TradeDesk {
  TradeDesk(
    this._stock, {
    required this.scaleOf,
    required this.earn,
    required this.requestRoll,
  }) {
    _sellAllYield = Computed(() {
      var sum = BigDouble.zero;
      for (final row in priceTable) {
        if (sellsInSweep(row.id)) sum += sellYield(row.id);
      }
      return sum;
    }, name: 'sell all yield');
  }

  final Stockpile _stock;

  /// The credits lane's financing multiplier, read at every sale.
  final BigDouble Function(ResourceId id) scaleOf;

  /// Where every credit income lands, whatever sold it.
  final void Function(BigDouble paid) earn;

  /// The board's own roll stream, fetched at call time: the source is
  /// swapped on a save load and the desk must follow it.
  final RandomStream Function() requestRoll;

  /// The price list. Fixed by design: no depth scaling, no market swings
  /// -- a pile of regolith is worth the same credits whenever it is sold,
  /// so "when to sell" is about what the player needs, never about
  /// timing. PROVISIONAL numbers, like every other constant here.
  static const List<({ResourceId id, double price})> priceTable = [
    (id: ResourceId.regolith, price: 0.4),
    (id: ResourceId.cuprite, price: 820),
    (id: ResourceId.ferrite, price: 1400),
    // Crafted goods carry a margin over what their inputs would fetch raw
    // (metals ~+35%, products ~+70%): crafting is meant to become the
    // best credit channel of the late run. PROVISIONAL.
    (id: ResourceId.cuprum, price: 45000),
    (id: ResourceId.ferrum, price: 76000),
    (id: ResourceId.silicon, price: 120000),
    (id: ResourceId.wire, price: 1.7e6),
    (id: ResourceId.frame, price: 2.7e6),
    (id: ResourceId.reinforcedGlass, price: 2.0e6),
    (id: ResourceId.chip, price: 4.0e6),
    (id: ResourceId.processor, price: 5.0e7),
    (id: ResourceId.sensor, price: 2.0e7),
    (id: ResourceId.module, price: 4.5e7),
  ];

  /// The shares a position can sell at. Steps rather than a free slider:
  /// four honest notches read at a glance, and the setting survives being
  /// toggled off without inventing a fifth "0%" state.
  static const List<int> sellShares = [25, 50, 75, 100];

  final Map<ResourceId, Signal<bool>> _selling = {
    for (final row in priceTable)
      row.id: Signal(true, name: 'selling ${row.id.name}'),
  };

  final Map<ResourceId, Signal<int>> _sellShare = {
    for (final row in priceTable)
      row.id: Signal(100, name: 'sell share ${row.id.name}'),
  };

  /// Whether "sell everything" takes this position. An off position keeps
  /// its colour, its share and its own sell button -- the toggle means
  /// one thing only.
  Signal<bool> sellingOf(ResourceId id) => _selling[id]!;

  /// Each shelf's switch, INDEPENDENT of the positions' own: turning the
  /// group off does not rewrite what each position chose, so turning it
  /// back on restores the exact picture the player had set up.
  final Map<String, Signal<bool>> _groupSelling = {
    for (final group in tradeGroupTable)
      group.key: Signal(true, name: 'selling ${group.key}'),
  };

  Signal<bool> sellingGroupOf(String key) => _groupSelling[key]!;

  /// Whether "sell everything" takes [id] right now: its own switch AND
  /// its shelf's.
  bool sellsInSweep(ResourceId id) {
    final key = tierKeyOf(id);
    return key != null && _groupSelling[key]!.value && _selling[id]!.value;
  }

  /// What share of the held amount a sale moves, in percent.
  Signal<int> sellShareOf(ResourceId id) => _sellShare[id]!;

  BigDouble sellPrice(ResourceId id) =>
      BigDouble.fromNum(priceTable.firstWhere((row) => row.id == id).price);

  /// The amount one manual sale of [id] would move right now.
  BigDouble sellLot(ResourceId id) =>
      _stock.amount(id) * BigDouble.fromNum(_sellShare[id]!.value / 100);

  /// What one manual sale of [id] pays right now, credit funding included.
  BigDouble sellYield(ResourceId id) =>
      sellLot(id) * sellPrice(id) * scaleOf(ResourceId.credits);

  /// What "sell everything" pays: only positions left switched on. The
  /// button quotes this same number, so it can never surprise.
  late final Computed<BigDouble> _sellAllYield;

  BigDouble get sellAllYield => _sellAllYield.value;

  /// Sells [id] at its share, toggle or no toggle: the per-position
  /// button is a manual override, and a manual act obeys the finger, not
  /// the flag.
  BigDouble sellPosition(ResourceId id) {
    final lot = sellLot(id);
    if (lot.isZero) return BigDouble.zero;
    final paid = sellYield(id);
    batch(() {
      _stock.spend(id, lot);
      earn(paid);
    });
    return paid;
  }

  /// Sells every position that is switched on. Returns the credits paid.
  BigDouble sellAll() {
    var paid = BigDouble.zero;
    batch(() {
      for (final row in priceTable) {
        if (sellsInSweep(row.id)) paid += sellPosition(row.id);
      }
    });
    return paid;
  }

  // ------------------------------------------------------------- requests

  /// How many requests can wait at once. A future tree node raises it.
  int get requestSlots => 3;

  /// How often a new request arrives, wall-clock. PROVISIONAL.
  static const int requestIntervalMs = 8 * 60 * 1000;

  /// How long a request waits before leaving. Expiry costs nothing: the
  /// premium is a bonus on top of list price, never a gate (safeguard 4).
  static const int requestLifetimeMs = 12 * 60 * 1000;

  static const double requestShareFloor = 0.15;
  static const double requestShareCeil = 0.45;
  static const double requestPremiumFloor = 0.15;
  static const double requestPremiumCeil = 0.40;
  static const double requestSecondLineChance = 0.45;

  /// The requests on the board, oldest first. Mutated only by
  /// [syncRequests] and [fulfilRequest]; redraws ride the app's own clock.
  final List<TradeRequest> requests = [];

  /// When the next courier is due. Zero means the board has never been
  /// looked at -- the first sync posts a request immediately, so the tab
  /// is never empty on first visit.
  int nextRequestAtMs = 0;

  /// Retires the expired, posts the due. Wall-clock like the drift, and
  /// for the same reason: couriers do not pause with the engines. A long
  /// absence posts at most a boardful -- the backlog is not replayed one
  /// by one.
  void syncRequests(int nowMs) {
    requests.removeWhere((request) => request.expiresAtMs <= nowMs);
    if (nextRequestAtMs == 0) nextRequestAtMs = nowMs;
    while (nextRequestAtMs <= nowMs) {
      if (requests.length >= requestSlots || !_spawnRequest(nowMs)) {
        // The board is full, or there is nothing to ask for yet: the next
        // courier comes a full interval from NOW, not the moment a slot
        // frees -- a freed slot is not a delivery.
        nextRequestAtMs = nowMs + requestIntervalMs;
        break;
      }
      nextRequestAtMs += requestIntervalMs;
    }
  }

  bool _spawnRequest(int nowMs) {
    // Only what the player actually holds is asked for: a request for an
    // ore the run has never seen would be a wall, and the amounts are
    // shares of the pile so they scale with progress by construction.
    final pool = [
      for (final row in priceTable)
        if (!_stock.amount(row.id).isZero) row.id,
    ];
    if (pool.isEmpty) return false;
    final roll = requestRoll();
    final lines = pool.length > 1 && roll.chance(requestSecondLineChance)
        ? 2
        : 1;
    final needs = <({ResourceId id, BigDouble amount})>[];
    for (var line = 0; line < lines; line++) {
      final id = pool.removeAt(roll.nextInt(pool.length));
      final share =
          requestShareFloor +
          (requestShareCeil - requestShareFloor) * roll.nextDouble();
      needs.add((id: id, amount: _stock.amount(id) * BigDouble.fromNum(share)));
    }
    final premium =
        requestPremiumFloor +
        (requestPremiumCeil - requestPremiumFloor) * roll.nextDouble();
    requests.add(
      TradeRequest(
        needs: needs,
        premium: premium,
        expiresAtMs: nowMs + requestLifetimeMs,
      ),
    );
    return true;
  }

  /// List price of everything the request wants, plus its premium.
  BigDouble requestPayout(TradeRequest request) {
    var sum = BigDouble.zero;
    for (final need in request.needs) {
      sum += need.amount * sellPrice(need.id);
    }
    // A request is a sale: the credits lane pays here too.
    return sum *
        BigDouble.fromNum(1 + request.premium) *
        scaleOf(ResourceId.credits);
  }

  bool canFulfil(TradeRequest request) =>
      request.needs.every((need) => _stock.has(need.id, need.amount));

  bool fulfilRequest(TradeRequest request) {
    if (!requests.contains(request) || !canFulfil(request)) return false;
    batch(() {
      for (final need in request.needs) {
        _stock.spend(need.id, need.amount);
      }
      earn(requestPayout(request));
    });
    requests.remove(request);
    return true;
  }

  // ----------------------------------------------------------------- save

  /// Only departures from the defaults are written: a fresh build reads
  /// an old save and every position simply sells whole, switched on.
  Map<String, Object?> toJson() => {
    if (_selling.values.any((signal) => !signal.value))
      'off': [
        for (final row in priceTable)
          if (!_selling[row.id]!.value) row.id.name,
      ],
    if (_groupSelling.values.any((signal) => !signal.value))
      'groupOff': [
        for (final group in tradeGroupTable)
          if (!_groupSelling[group.key]!.value) group.key,
      ],
    if (_sellShare.values.any((signal) => signal.value != 100))
      'share': {
        for (final row in priceTable)
          if (_sellShare[row.id]!.value != 100)
            row.id.name: _sellShare[row.id]!.value,
      },
    'nextAt': nextRequestAtMs,
    'requests': [for (final request in requests) request.toJson()],
  };

  void readJson(Object? json) {
    requests.clear();
    if (json is! Map) {
      for (final row in priceTable) {
        _selling[row.id]!.value = true;
        _sellShare[row.id]!.value = 100;
      }
      for (final group in tradeGroupTable) {
        _groupSelling[group.key]!.value = true;
      }
      nextRequestAtMs = 0;
      return;
    }
    final off = json['off'];
    final share = json['share'];
    for (final row in priceTable) {
      _selling[row.id]!.value = off is! List || !off.contains(row.id.name);
      final stored = share is Map ? share[row.id.name] : null;
      _sellShare[row.id]!.value = sellShares.contains(stored)
          ? stored as int
          : 100;
    }
    final groupOff = json['groupOff'];
    for (final group in tradeGroupTable) {
      // The legacy shape was a bare `true` meaning the one shelf of the
      // three-row era; it lands on the resources shelf.
      final off = groupOff is List
          ? groupOff.contains(group.key)
          : groupOff == true && group.key == 'resources';
      _groupSelling[group.key]!.value = !off;
    }
    final nextAt = json['nextAt'];
    nextRequestAtMs = nextAt is num ? nextAt.toInt() : 0;
    final posted = json['requests'];
    if (posted is List) {
      for (final entry in posted) {
        final request = TradeRequest.fromJson(entry);
        if (request != null) requests.add(request);
      }
    }
  }
}
