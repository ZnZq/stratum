import '../big_double.dart';
import '../reactive_graph.dart';
import '../stockpile.dart';
import 'craft_line.dart';
import 'craft_recipe.dart';
import 'craft_shop.dart';
import 'trade_desk.dart';

/// Auto-craft: points every bench that stands idle, starved or finished
/// at the most valuable job it can feed right now -- the recipe and
/// compression whose output, at list price, pays the most per second
/// and whose first unit the store can cover. Endless mode: the planner
/// re-plans when the line runs dry. ONLINE ONLY.
class AutoCrafter {
  AutoCrafter(this._stock, this._shop, this._desk);

  final Stockpile _stock;
  final CraftShop _shop;
  final TradeDesk _desk;

  final Signal<bool> enabled = Signal(true, name: 'auto craft on');

  /// The lines the planner is currently driving, so the screen can say
  /// so. Not saved: it is rebuilt by the first run after a load.
  final Signal<Set<int>> managed = Signal(const {}, name: 'auto craft managed');

  bool manages(int index) => managed.value.contains(index);

  /// The best job a line could run: value per second at list price,
  /// feasible for at least one unit.
  ({ResourceId output, int tier, double score})? bestJob(CraftLine line) {
    ({ResourceId output, int tier, double score})? best;
    final speed = craftSpeedAt(line.speedLevel.value) * craftGameSpeed;
    for (final recipe in craftTable) {
      final price = _desk.sellPrice(recipe.output).toDouble();
      for (var tier = 0; tier <= line.tierCap.value; tier++) {
        if (!_feeds(recipe, tier)) continue;
        final score =
            price *
            craftUnitsAt(recipe, tier) /
            craftSecondsAt(recipe, tier, speed);
        if (best == null || score > best.score) {
          best = (output: recipe.output, tier: tier, score: score);
        }
      }
    }
    return best;
  }

  bool _feeds(CraftRecipe recipe, int tier) {
    final scale = craftCostScaleAt(tier);
    for (final entry in recipe.inputs.entries) {
      final need = BigDouble.fromNum(entry.value * scale);
      if (!_stock.amount(entry.key).gteWithTolerance(need)) return false;
    }
    return true;
  }

  /// Re-plans every line that is not busy. Returns how many were pointed
  /// somewhere new.
  int run() {
    if (!enabled.value) return 0;
    var moved = 0;
    final driving = Set<int>.of(managed.value);
    for (var i = 0; i < _shop.lines.length; i++) {
      final line = _shop.lines[i];
      final idle =
          line.recipe.value == null ||
          line.done ||
          (line.starving.value && !line.unitLoaded.value);
      if (!idle) continue;
      final job = bestJob(line);
      if (job == null) continue;
      if (line.recipe.value == job.output &&
          line.tier.value == job.tier &&
          !line.done &&
          !line.starving.value) {
        continue;
      }
      _shop.assign(i, job.output, tier: job.tier);
      driving.add(i);
      moved++;
    }
    if (moved > 0) managed.value = driving;
    return moved;
  }

  Map<String, Object?> toJson() => {if (!enabled.value) 'off': true};

  void readJson(Object? json) {
    enabled.value = !(json is Map && json['off'] == true);
    managed.value = const {};
  }
}
