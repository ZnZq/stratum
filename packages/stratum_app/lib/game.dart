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
    drill.start();
  }

  static final TickRate baseRate = TickRate(const Duration(seconds: 4));
  static final TickRate forcingRate = TickRate(const Duration(seconds: 1));

  /// One point of charge every five seconds fills the gauge in the same eight
  /// and a bit minutes the prototype took, only without borrowing the drill's
  /// heartbeat to do it.
  static final TickRate chargeRate = TickRate(const Duration(seconds: 5));

  final PrototypeSimulation sim = PrototypeSimulation();

  late final TickEngine drill;
  late final TickEngine chargeLoop;

  final List<FloatingNumber> floats = [];
  int _nextFloatId = 0;

  /// Bumped whenever the scene should flash for a critical or a broken layer.
  final ValueNotifier<int> criticalFlashes = ValueNotifier(0);
  final ValueNotifier<int> breakFlashes = ValueNotifier(0);

  bool get isForcing => sim.forcing.value;

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
        text: 'ТОВСТИЙ ШАР · всі ресурси ×5',
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
    floats.add(FloatingNumber(
      id: _nextFloatId++,
      text: text,
      color: color,
      left: left,
      top: top,
      size: size,
    ));
  }

  void retireFloat(int id) {
    floats.removeWhere((f) => f.id == id);
  }

  void startForcing() {
    if (sim.charge.value <= 2 || sim.forcing.value) return;
    sim.forcing.value = true;
    drill.rate = forcingRate;
    notifyListeners();
  }

  void stopForcing() {
    if (!sim.forcing.value) return;
    sim.forcing.value = false;
    drill.rate = baseRate;
    _syncChargeLoop();
    notifyListeners();
  }

  void buyDrill() {
    sim.buyDrill();
    notifyListeners();
  }

  @override
  void dispose() {
    drill.dispose();
    chargeLoop.dispose();
    criticalFlashes.dispose();
    breakFlashes.dispose();
    super.dispose();
  }
}
