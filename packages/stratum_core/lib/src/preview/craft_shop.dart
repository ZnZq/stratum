import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'craft_line.dart';
import 'craft_recipe.dart';

/// The benches: every [CraftLine] the player owns, their purchases, and
/// the walk that turns wall time into prepaid units. One walk serves the
/// online sync and the sliced absence settlement alike -- the offline
/// parity invariant is kept by construction, not by an integral.
class CraftShop {
  CraftShop(this._stock) {
    for (var i = 0; i < craftStartLines; i++) {
      lines.add(CraftLine(_stock, i));
    }
  }

  final Stockpile _stock;

  /// The machines. Two to start with; the rest are bought with credits.
  final List<CraftLine> lines = [];

  /// The last acknowledged-clock stamp [sync] settled to; -1 = never.
  /// Acknowledged-clock units, so the 48h absence cap is inherited.
  int lastSeenMs = -1;

  /// Advances every line to the acknowledged stamp [seen] and returns what
  /// the span produced, for the offline window. One formula from the time
  /// delta -- identical online and offline, per the house rule; the pause
  /// melts under it like the drift and the request board do.
  Map<ResourceId, BigDouble> sync(int seen) {
    if (lastSeenMs < 0) {
      lastSeenMs = seen;
      return const {};
    }
    final span = (seen - lastSeenMs) / 1000.0;
    lastSeenMs = seen;
    if (span <= 0) return const {};
    final made = <ResourceId, BigDouble>{};
    batch(() => run(span, made));
    return made;
  }

  /// Walks every line through [span] seconds, adding what they deliver
  /// to [made]. The absence settlement calls this slice by slice.
  void run(
    double span,
    Map<ResourceId, BigDouble> made, {
    bool offline = false,
  }) {
    for (final line in lines) {
      _runLine(line, span, made, offline: offline);
    }
  }

  void _runLine(
    CraftLine line,
    double span,
    Map<ResourceId, BigDouble> made, {
    required bool offline,
  }) {
    final row = craftRecipeOf(line.recipe.value);
    if (line.halted.value) {
      // A hand-stop is a FREEZE-FRAME: progress, boost and the picture
      // all hold exactly where they were until the player resumes.
      return;
    }
    if (row == null || line.done) return;
    // The walk goes UNIT BY UNIT. A unit is prepaid on start and delivered
    // whole on finish; each finish may add a boost stack, which speeds up
    // every unit after it. Stepping through them keeps one long span
    // identical to the same span in pieces -- the offline-parity invariant.
    var remaining = span;
    var guard = 0;
    while (remaining > 1e-9 && guard++ < 700000) {
      if (!line.unitLoaded.value && !_loadUnit(line, row)) {
        // Standing hungry drains the warm-up: a stack dies for every
        // [craftBoostDecaySeconds] of starvation, the remainder banked
        // so a long span equals the same span in pieces.
        final bank = line.starveBank.value + remaining;
        final lost = bank ~/ craftBoostDecaySeconds;
        if (lost > 0 && line.boostStacks.value > 0) {
          final left = line.boostStacks.value - lost;
          line.boostStacks.value = left < 0 ? 0 : left;
        }
        line.starveBank.value = bank % craftBoostDecaySeconds;
        break;
      }
      // The bench is fed and working: the hunger bank starts over.
      line.starveBank.value = 0;
      final eff = line.craftSeconds.value;
      final timeLeft = (1 - line.unitFraction.value) * eff;
      if (remaining < timeLeft - 1e-12) {
        line.unitFraction.value = line.unitFraction.value + remaining / eff;
        break;
      }
      remaining -= timeLeft;
      final ordinal = line.unitOrdinal.value;
      // An absence pays the floor: no duplicate rolls and no new boost
      // stacks (owner's rule) -- chance is a bonus for the present eye.
      // The ordinal still advances, so the coins resume deterministically
      // from the right place when the player returns.
      final doubled = !offline && craftDuplicateRoll(ordinal);
      if (doubled) line.dupCount.value = line.dupCount.value + 1;
      final units = line.unitsPerCraft.value * (doubled ? 2 : 1);
      final out = BigDouble.fromNum(units);
      _stock.add(row.output, out);
      made[row.output] = (made[row.output] ?? BigDouble.zero) + out;
      line.producedCount.value = line.producedCount.value + units;
      line.unitFraction.value = 0;
      line.unitLoaded.value = false;
      line.unitOrdinal.value = ordinal + 1;
      if (!offline &&
          line.boostStacks.value < craftBoostCap &&
          craftBoostRoll(ordinal)) {
        line.boostStacks.value = line.boostStacks.value + 1;
      }
      if (line.done) break;
    }
  }

  /// Takes one unit's full inputs from the stock, or refuses untouched:
  /// the unit is PREPAID, all or nothing.
  bool _loadUnit(CraftLine line, CraftRecipe row) {
    final scale = craftCostScaleAt(line.tier.value);
    for (final entry in row.inputs.entries) {
      final need = BigDouble.fromNum(entry.value * scale);
      if (!_stock.amount(entry.key).gteWithTolerance(need)) return false;
    }
    for (final entry in row.inputs.entries) {
      final need = BigDouble.fromNum(entry.value * scale);
      final held = _stock.amount(entry.key);
      _stock.spend(entry.key, need.gteWithTolerance(held) ? held : need);
    }
    line.unitLoaded.value = true;
    return true;
  }

  /// Puts a loaded, unfinished unit's inputs back on the shelf -- the
  /// cancel path. Uses the line's CURRENT recipe and tier, so it must run
  /// before either changes.
  void _refundUnit(CraftLine line) {
    if (!line.unitLoaded.value) return;
    final row = craftRecipeOf(line.recipe.value);
    if (row != null) {
      final scale = craftCostScaleAt(line.tier.value);
      for (final entry in row.inputs.entries) {
        _stock.add(entry.key, BigDouble.fromNum(entry.value * scale));
      }
    }
    line.unitLoaded.value = false;
  }

  /// Assigns what the line makes and the run mode, chosen together in the
  /// picker. A fresh order restarts the count toward [limit] (-1 =
  /// endless) and the warm-up: the boost belongs to the job. The unit in
  /// progress is scrapped and its prepaid inputs go back on the shelf --
  /// cancelling never costs resources (owner's rule). Assigning is
  /// launching a NEW order, so the compression level may be chosen with
  /// it -- the mid-job lock guards a RUNNING job, not this.
  void assign(int index, ResourceId? output, {int limit = -1, int? tier}) {
    final line = lines[index];
    _refundUnit(line);
    line.recipe.value = craftRecipeOf(output)?.output;
    line.limit.value = limit;
    line.producedCount.value = 0;
    line.halted.value = false;
    line.unitFraction.value = 0;
    line.boostStacks.value = 0;
    line.unitOrdinal.value = 0;
    line.dupCount.value = 0;
    if (tier != null) {
      line.tier.value = tier.clamp(0, line.tierCap.value);
    }
  }

  /// Stops or resumes the line by hand: a freeze-frame. The machine keeps
  /// its recipe, its order, its loaded unit and its boost, and frees the
  /// compression level while it stands.
  void setHalted(int index, bool value) {
    lines[index].halted.value = value;
  }

  /// Picks the compression level. Refused while the line is running: the
  /// level is fixed for the length of a job, changeable the moment the
  /// machine stands.
  bool setTier(int index, int value) {
    final line = lines[index];
    if (line.running) return false;
    final clamped = value.clamp(0, line.tierCap.value);
    if (clamped != line.tier.value) {
      // A different compression is a different JOB: the unit in progress
      // is refunded (at the OLD tier it was paid at), and the next one
      // starts from zero with a cold boost (owner's rule).
      _refundUnit(line);
      line.tier.value = clamped;
      line.unitFraction.value = 0;
      line.boostStacks.value = 0;
      line.unitOrdinal.value = 0;
      line.dupCount.value = 0;
    }
    return true;
  }

  // ------------------------------------------------------------ purchases

  BigDouble get lineCost =>
      BigDouble.fromNum(2000) *
      BigDouble.fromNum(6).pow((lines.length - craftStartLines).toDouble());

  bool get canBuyLine => _stock.has(ResourceId.credits, lineCost);

  bool buyLine() {
    if (!_stock.spend(ResourceId.credits, lineCost)) return false;
    lines.add(CraftLine(_stock, lines.length));
    return true;
  }

  BigDouble capCost(int index) =>
      BigDouble.fromNum(500) *
      BigDouble.fromNum(4).pow(lines[index].tierCap.value.toDouble());

  bool canBuyCap(int index) =>
      lines[index].tierCap.value < craftTierCapMax &&
      _stock.has(ResourceId.credits, capCost(index));

  /// Raises the line's compression ceiling. The CHOSEN level never moves
  /// with the purchase: standing below the ceiling is a legitimate trade,
  /// not an oversight.
  bool buyCap(int index) {
    if (!canBuyCap(index)) return false;
    if (!_stock.spend(ResourceId.credits, capCost(index))) return false;
    final line = lines[index];
    line.tierCap.value = line.tierCap.value + 1;
    return true;
  }

  BigDouble speedCost(int index) =>
      BigDouble.fromNum(300) *
      BigDouble.fromNum(1.6).pow(lines[index].speedLevel.value.toDouble());

  bool canBuySpeed(int index) =>
      _stock.has(ResourceId.credits, speedCost(index));

  bool buySpeed(int index) {
    if (!_stock.spend(ResourceId.credits, speedCost(index))) return false;
    final line = lines[index];
    line.speedLevel.value = line.speedLevel.value + 1;
    return true;
  }

  // ----------------------------------------------------------------- save

  Map<String, Object?> toJson() => {
    'last': lastSeenMs,
    'lines': [for (final line in lines) line.toJson()],
  };

  /// Restores the benches, topping up to the starting count when a save
  /// holds fewer -- the self-healing for a changed [craftStartLines].
  void readJson(Object? json) {
    lines.clear();
    if (json is Map) {
      final last = json['last'];
      lastSeenMs = last is num ? last.toInt() : -1;
      final stored = json['lines'];
      if (stored is List) {
        for (var i = 0; i < stored.length; i++) {
          lines.add(CraftLine(_stock, i)..readJson(stored[i]));
        }
      }
    } else {
      lastSeenMs = -1;
    }
    while (lines.length < craftStartLines) {
      lines.add(CraftLine(_stock, lines.length));
    }
  }
}
