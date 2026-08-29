import 'big_double.dart';
import 'reactive_graph.dart';

/// Everything the player can hold.
///
/// One flat list rather than a field per resource: the warehouse renders it by
/// walking the values, so a satellite material added later is one more entry
/// instead of a new signal wired into every place that shows a total.
enum ResourceId {
  /// Ground rock: what a drill actually leaves behind. Every cycle, always.
  regolith,

  /// Copper-bearing ore. The first chance drop.
  cuprite,

  /// Iron-bearing ore, from the second stratum down.
  ferrite,

  /// Silicon-bearing mineral, from the third stratum down.
  silicite,

  /// The gem tier. Drops by chance, and the deeper the shaft the more of it
  /// comes up at once.
  crystals,

  /// Restart currency, dropped by chance for a completed cycle rather than for
  /// breaking a layer -- the anti-brick rule.
  quantonium,

  /// What mined resources sell for. Buys rig upgrades; a Restart wipes it.
  /// No income yet -- selling is its own step.
  credits,

  /// Fragments of the simulation's own substrate, dug out of the rock like
  /// anything else. The restart currency before it is compiled.
  rawData,

  /// One per first break of a thick layer within a simulation.
  samples,

  /// Bought with a Restart.
  capsules,

  /// Bought with a Collapse.
  cores,

  /// Background compute, generated only while offline.
  compute,
}

/// What the player owns.
///
/// Unbounded by design: the store is infinite and no resource has a cap, so
/// nothing here clamps. Every amount is a [Signal], so a readout that shows one
/// resource is not woken by another one changing.
class Stockpile {
  Stockpile() {
    for (final id in ResourceId.values) {
      _held[id] = Signal(BigDouble.zero, name: 'stock.${id.name}');
    }
  }

  final Map<ResourceId, Signal<BigDouble>> _held = {};

  Signal<BigDouble> signal(ResourceId id) => _held[id]!;

  BigDouble amount(ResourceId id) => _held[id]!.value;

  void add(ResourceId id, BigDouble value) {
    if (value.isZero) return;
    final held = _held[id]!;
    held.value = held.value + value;
  }

  /// Whether [cost] is affordable.
  ///
  /// Compared with tolerance: a player holding exactly the price must never be
  /// told they are short by a rounding error.
  bool has(ResourceId id, BigDouble cost) => amount(id).gteWithTolerance(cost);

  bool spend(ResourceId id, BigDouble cost) {
    if (!has(id, cost)) return false;
    final held = _held[id]!;
    held.value = held.value - cost;
    return true;
  }

  /// Empties the given resources, for what a Restart or a Collapse wipes.
  void clear(Iterable<ResourceId> ids) => batch(() {
    for (final id in ids) {
      _held[id]!.value = BigDouble.zero;
    }
  });

  void dispose() {
    for (final held in _held.values) {
      held.dispose();
    }
  }

  /// Only what is actually held is written: a resource the player has never
  /// seen costs nothing in the save, and reading a save without it back gives
  /// zero anyway.
  Map<String, Object?> toJson() => {
    for (final entry in _held.entries)
      if (!entry.value.value.isZero) entry.key.name: entry.value.value.toJson(),
  };

  void readJson(Map<String, Object?> json) => batch(() {
    for (final id in ResourceId.values) {
      final raw = json[id.name];
      _held[id]!.value = raw is String ? BigDouble.parse(raw) : BigDouble.zero;
    }
  });
}
