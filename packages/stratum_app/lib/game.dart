import 'package:flutter/foundation.dart';
import 'package:stratum_core/stratum_core.dart';

/// A number that flew off a cycle, for the scene to animate and forget.
class FloatingNumber {
  FloatingNumber({
    required this.id,
    required this.text,
    required this.color,
    required this.left,
    required this.top,
    required this.size,
  });

  final int id;
  final String text;
  final int color;
  final double left;
  final double top;
  final double size;
}

/// Owns the simulation and the loops that drive it.
///
/// Two engines, not one. The drill beats every four seconds and does the
/// mining; the forcing charge regenerates on its own slower loop that stops
/// itself once the charge is full and resumes when the player spends some.
/// Stopping the drill loop for a full charge would freeze the mining too.
class Game extends ChangeNotifier {
  Game() {
    drill = TickEngine(
      scheduler: TickScheduler(rate: baseRate),
      onBatch: _onDrillBatch,
    );
    chargeLoop = TickEngine(
      scheduler: TickScheduler(rate: chargeRate),
      onBatch: _onChargeBatch,
    );

    // The simulation owns whether forcing is on, and it can switch it off by
    // itself when the charge runs out. Subscribing means the drill rate always
    // follows that one flag instead of being set alongside it and drifting.
    _forcingWatch = sim.forcing.listen(_applyDrillRate);
    drill.start();
  }

  static final TickRate baseRate = TickRate(const Duration(seconds: 4));

  /// Forcing halves the heartbeat rather than pinning it to a fixed length,
  /// so anything that shortens the base tick later carries through by itself.
  static final TickRate forcingRate = TickRate(
    Duration(microseconds: baseRate.interval.inMicroseconds ~/ 2),
  );

  /// One point of charge every two seconds, on its own loop rather than
  /// borrowing the drill's heartbeat. The meter above the readout is driven
  /// by this engine, so what the player watches filling is the real interval.
  static final TickRate chargeRate = TickRate(const Duration(seconds: 2));

  final PrototypeSimulation sim = PrototypeSimulation();

  late final TickEngine drill;
  late final TickEngine chargeLoop;
  late final Unsubscribe _forcingWatch;

  void _applyDrillRate() {
    final wanted = sim.forcing.value ? forcingRate : baseRate;
    if (identical(drill.rate, wanted)) return;
    drill.rate = wanted;
  }

  final List<FloatingNumber> floats = [];
  int _nextFloatId = 0;

  /// Bumped whenever the scene should flash for a critical or a broken layer.
  final ValueNotifier<int> criticalFlashes = ValueNotifier(0);
  final ValueNotifier<int> breakFlashes = ValueNotifier(0);

  bool get isForcing => sim.forcing.value;

  /// The heartbeat as it currently stands, forcing included.
  String get tickInterval => secondsLabel(drill.rate.interval);

  /// How long one point of charge takes, for the gauge to say so out loud.
  static String get chargeInterval => secondsLabel(chargeRate.interval);

  static String secondsLabel(Duration interval) =>
      '${(interval.inMilliseconds / 1000).toStringAsFixed(1)} с';

  void _onDrillBatch(TickBatch batch) {
    for (var i = 0; i < batch.ticks; i++) {
      final outcome = sim.tick();
      _reportCycle(outcome);
    }
    _syncChargeLoop();
    notifyListeners();
  }

  void _onChargeBatch(TickBatch batch) {
    for (var i = 0; i < batch.ticks; i++) {
      sim.regenerateCharge();
    }
    if (sim.chargeFull) chargeLoop.stop();
    if (_gripHeld) _engageForcing();
    notifyListeners();
  }

  /// The charge loop sleeps while the gauge is full, so spending has to wake it.
  void _syncChargeLoop() {
    if (sim.chargeFull) {
      if (chargeLoop.isRunning) chargeLoop.stop();
    } else if (!chargeLoop.isRunning) {
      chargeLoop.start();
    }
  }

  void _reportCycle(CycleOutcome outcome) {
    final gained = outcome.oreGained.toString(NumberStyle.compact);
    _addFloat(
      text: outcome.critical ? '+$gained · КРИТ' : '+$gained',
      color: outcome.critical ? 0xFFFFD782 : 0xFFC9CCD6,
      left: 26 + (outcome.layersBroken * 17 % 120).toDouble(),
      top: 92 + (outcome.quantoniumGained * 11 % 30).toDouble(),
      size: outcome.critical ? 27 : 16,
    );

    if (outcome.critical) {
      criticalFlashes.value = criticalFlashes.value + 1;
    }
    if (outcome.quantoniumGained > 0) {
      _addFloat(
        text: '+${outcome.quantoniumGained} КВ',
        color: 0xFFED93B1,
        left: 240,
        top: 118,
        size: 15,
      );
    }
    if (outcome.thickLayersBroken > 0) {
      _addFloat(
        text: 'ТОВСТИЙ ШАР · всі ресурси ×${PrototypeSimulation.thickSpan}',
        color: 0xFFFFD782,
        left: 28,
        top: 42,
        size: 16,
      );
    }
    if (outcome.layersBroken > 0) {
      breakFlashes.value = breakFlashes.value + 1;
    }
    if (outcome.echoes > 0) {
      _addFloat(
        text: 'ехо · подвійний удар',
        color: 0xFF9FE1CB,
        left: 104,
        top: 70,
        size: 14,
      );
    }
  }

  void _addFloat({
    required String text,
    required int color,
    required double left,
    required double top,
    required double size,
  }) {
    floats.add(
      FloatingNumber(
        id: _nextFloatId++,
        text: text,
        color: color,
        left: left,
        top: top,
        size: size,
      ),
    );
  }

  void retireFloat(int id) {
    floats.removeWhere((f) => f.id == id);
  }

  /// Whether the player is still pressing the rock.
  ///
  /// Kept apart from [PrototypeSimulation.forcing], which the simulation
  /// clears on its own when the gauge runs dry. The press outlives that, so
  /// forcing resumes by itself as soon as a point is back instead of asking
  /// the player to lift and press again.
  bool _gripHeld = false;

  void startForcing() {
    _gripHeld = true;
    _engageForcing();
  }

  void stopForcing() {
    _gripHeld = false;
    if (!sim.forcing.value) return;
    sim.forcing.value = false;
    _syncChargeLoop();
    notifyListeners();
  }

  void _engageForcing() {
    if (sim.forcing.value || !sim.beginForcing()) return;
    _syncChargeLoop();
    notifyListeners();
  }

  void buyDrill() {
    sim.buyDrill();
    notifyListeners();
  }

  void buyPowerUpgrade() {
    sim.buyPowerUpgrade();
    notifyListeners();
  }

  @override
  void dispose() {
    _forcingWatch();
    drill.dispose();
    chargeLoop.dispose();
    criticalFlashes.dispose();
    breakFlashes.dispose();
    super.dispose();
  }
}
