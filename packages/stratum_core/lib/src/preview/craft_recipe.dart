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
    // Short on purpose for now: the owner wants the fast-craft animation
    // observable at the one-second floor. PROVISIONAL like the rest.
    baseSeconds: 4,
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

/// The warm-up, counted in whole STACKS: every finished unit has this
/// chance to add one, each stack is +[craftBoostStep] craft speed, and the
/// pile is capped at [craftBoostCap] (a future upgrade raises the cap).
/// Changing the recipe or the compression resets the pile -- the boost
/// belongs to the JOB. PROVISIONAL numbers.
const double craftBoostChance = 0.25;
const int craftBoostCap = 15;
const double craftBoostStep = 0.01;

/// A starving bench cannot hold its warm-up: every this-many seconds of
/// standing hungry, one stack dies. A freeze-frame (hand stop) does NOT
/// decay -- frozen is frozen. PROVISIONAL.
const double craftBoostDecaySeconds = 5;

/// The chance a finished unit pays double. A real per-unit roll now that
/// units are whole things. Bonus on top, never a gate. PROVISIONAL.
const double craftDuplicateChance = 0.05;

/// Both craft rolls are deterministic Knuth-style hashes of the unit's
/// ordinal within the job: the game's real RNG streams stay untouched, the
/// walk replays identically, and offline parity holds by construction.
/// Different primes so the two coins never correlate; the +1 keeps
/// ordinal zero from hashing to a guaranteed win.
bool craftBoostRoll(int ordinal) =>
    (((ordinal + 1) * 2654435761) & 0xFFFF) / 0xFFFF < craftBoostChance;

bool craftDuplicateRoll(int ordinal) =>
    (((ordinal + 1) * 2246822519) & 0xFFFF) / 0xFFFF < craftDuplicateChance;

/// Global craft-speed sources (tree nodes, ranks) multiply in here; the
/// backer has nothing yet.
const double craftGameSpeed = 1;

/// The floor under a craft: however far the speed track and the warm-up
/// go, one unit can never take less than a second. The ceiling is what
/// gives the speed track a finite worth -- the drill-drive lesson.
const double craftMinSeconds = 1;

/// Lines the player starts with; the rest are bought with credits.
const int craftStartLines = 2;
