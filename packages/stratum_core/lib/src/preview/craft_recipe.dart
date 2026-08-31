import '../stockpile.dart';

/// One craft recipe: what a single craft at compression 1x consumes, what it
/// yields and how long it takes. A new recipe is a table row, not a branch.
class CraftRecipe {
  const CraftRecipe({
    required this.output,
    required this.inputs,
    required this.baseSeconds,
    this.baseYield = 1,
  });

  final ResourceId output;

  /// Per one craft at compression level 0. Level t multiplies every entry
  /// by [craftCostStep]^t.
  final Map<ResourceId, double> inputs;

  /// At compression level 0, before the line's speed and the ramp.
  final double baseSeconds;

  /// Output units per craft at level 0; level t multiplies by
  /// [craftYieldStep]^t, and the duplicate chance rides on top as an
  /// expectation (the conversion is continuous, so a discrete roll would
  /// break offline parity).
  final double baseYield;
}

/// The recipe book. Smelting eats regolith as flux on purpose: crafting is
/// the sink for the one resource that never stops inflating. PROVISIONAL.
const List<CraftRecipe> craftTable = [
  CraftRecipe(
    output: ResourceId.cuprum,
    inputs: {ResourceId.cuprite: 8, ResourceId.regolith: 200},
    baseSeconds: 30,
  ),
  CraftRecipe(
    output: ResourceId.ferrum,
    inputs: {ResourceId.ferrite: 8, ResourceId.regolith: 300},
    baseSeconds: 45,
  ),
  CraftRecipe(
    output: ResourceId.silicon,
    inputs: {ResourceId.silicite: 6, ResourceId.regolith: 400},
    baseSeconds: 60,
  ),
  CraftRecipe(
    output: ResourceId.wire,
    inputs: {ResourceId.cuprum: 6, ResourceId.ferrum: 2},
    baseSeconds: 120,
  ),
  CraftRecipe(
    output: ResourceId.frame,
    inputs: {ResourceId.ferrum: 8, ResourceId.silicon: 4},
    baseSeconds: 180,
  ),
  CraftRecipe(
    output: ResourceId.chip,
    inputs: {
      ResourceId.silicon: 10,
      ResourceId.cuprum: 4,
      ResourceId.crystals: 5,
    },
    baseSeconds: 300,
  ),
];

CraftRecipe? craftRecipeOf(ResourceId? id) {
  if (id == null) return null;
  for (final recipe in craftTable) {
    if (recipe.output == id) return recipe;
  }
  return null;
}

/// The compression triple, taken from CHAD's forge verbatim: each level
/// doubles the yield, triples the inputs and stretches the craft x1.5 --
/// so a unit costs x1.5 more per level, which is the whole point: the sink
/// against inflation the GDD pinned as L^1.585.
const double craftYieldStep = 2;
const double craftCostStep = 3;
const double craftTimeStep = 1.5;

/// Where a line's compression track ends for good (16384x, CHAD's ceiling).
const int craftTierCapMax = 14;

/// Each speed level multiplies the line's pace -- the rate, never the
/// interval, so the reading cannot cross zero (the energy-regen lesson).
const double craftSpeedStep = 0.05;

/// A line that keeps converting warms up to this bonus over
/// [craftRampFullSeconds]. Starving or standing idle resets the warm-up;
/// changing the recipe does NOT -- the ramp belongs to the line, and the
/// screen is built for players who retarget it all day.
const double craftRampBonus = 0.25;
const double craftRampFullSeconds = 600;

/// The chance a craft pays double, folded into the yield as an expectation:
/// the conversion is continuous and must stay deterministic for offline
/// parity. Bonus on top, never a gate. PROVISIONAL.
const double craftDuplicateChance = 0.05;

/// Global craft-speed sources (tree nodes, ranks) multiply in here; the
/// backer has nothing yet.
const double craftGameSpeed = 1;

/// Lines the player starts with; the rest are bought with credits.
const int craftStartLines = 2;
