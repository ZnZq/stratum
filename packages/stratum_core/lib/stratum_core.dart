/// The STRATUM game core: tick engine, simulation state, balance, offline math.
///
/// This package does NOT depend on Flutter and must never reference it. Every
/// piece here has to run under plain `dart test` without an emulator, so that
/// "N ticks in milliseconds" stays a usable way to check balance curves.
library;

export 'src/balance_harness.dart';
export 'src/big_double.dart';
export 'src/number_style.dart';
export 'src/preview/arm_part.dart';
export 'src/preview/craft_line.dart';
export 'src/preview/craft_recipe.dart';
export 'src/preview/cycle_outcome.dart';
export 'src/preview/drill_id.dart';
export 'src/preview/drill_part.dart';
export 'src/preview/drill_row.dart';
export 'src/preview/drill_state.dart';
export 'src/preview/offline_gain.dart';
export 'src/preview/prototype_simulation.dart';
export 'src/preview/strike_outcome.dart';
export 'src/preview/trade_request.dart';
export 'src/random_source.dart';
export 'src/reactive_graph.dart';
export 'src/save_codec.dart';
export 'src/stockpile.dart';
export 'src/tick_engine.dart';
export 'src/tick_scheduler.dart';
