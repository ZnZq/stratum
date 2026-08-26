import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'save_store.dart';

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
  Game({SaveStore? store}) : store = store ?? SaveStore() {
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

    // The timer is the floor, not the plan: what actually protects a run is
    // saving the moment the player stops looking at it. Desktop windows close
    // without ever going inactive, so the exit hook is the only chance to
    // write the last few seconds of play.
    _lifecycle = AppLifecycleListener(
      onInactive: () => unawaited(saveTo(SaveSlot.auto)),
      // Hidden is where frames stop but the simulation, by design, does not:
      // an idle game keeps living in a minimised window. What must NOT keep
      // living is the effects queue -- floats are only retired when their
      // animation ends, and with no frames nothing ever ends, so the whole
      // absence would pour onto the first frame back.
      onHide: () {
        _hidden = true;
        unawaited(saveTo(SaveSlot.auto));
      },
      onShow: () {
        _hidden = false;
        floats.clear();
        notifyListeners();
      },
      onPause: () => unawaited(saveTo(SaveSlot.auto)),
      onDetach: () => unawaited(saveTo(SaveSlot.auto)),
      onExitRequested: () async {
        await saveTo(SaveSlot.auto);
        return AppExitResponse.exit;
      },
    );
  }

  final SaveStore store;

  /// Bumped whenever the shape of a save changes, with a migration to match.
  /// A gap in the chain is an error rather than a silent skip -- see
  /// [SaveCodec].
  static final SaveCodec codec = SaveCodec(currentVersion: 1);

  /// Housekeeping on wall-clock, not a game rhythm: a missed save must be
  /// forgotten rather than repaid, so this is a plain timer and not a
  /// [TickEngine] with its catch-up.
  ///
  /// Five minutes is the backstop for a session nobody interrupts. Losing
  /// focus, hiding and closing all save as well, so the window a crash can
  /// actually take is the time since the player last looked away.
  static const Duration autosaveEvery = Duration(minutes: 5);

  late final AppLifecycleListener _lifecycle;
  Timer? _autosave;

  /// Whether the save has been read. The loops stay parked until it has, so a
  /// cycle never runs against a default state that is about to be replaced.
  bool get ready => _ready;
  bool _ready = false;

  /// Whether the game is deliberately frozen.
  bool get paused => _paused;
  bool _paused = false;

  /// Freezes the whole heartbeat: drilling, charge, forcing.
  ///
  /// Both engines stop through [TickEngine.stop], which banks the time already
  /// served -- so the cycle ring and the charge sweep freeze mid-fill and
  /// carry on from the same spot on resume, rather than snapping back.
  void pause() {
    if (_paused || !_ready) return;
    _paused = true;
    _gripHeld = false;
    drill.stop();
    chargeLoop.stop();
    // A pause is a natural walking-away point, so bank the run while at it.
    unawaited(saveTo(SaveSlot.auto));
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    drill.start();
    _syncChargeLoop();
    notifyListeners();
  }

  /// When the autosave was last written, for the menu to show.
  DateTime? get lastSavedAt => _lastSavedAt;
  DateTime? _lastSavedAt;

  /// A write already in flight. A second one must not start on top of it: two
  /// writers racing on the same file is how a half-written save happens even
  /// with an atomic rename.
  Future<void>? _writing;

  /// Time played, carried across loads.
  ///
  /// Counted from a monotonic stopwatch and banked into the save, so it
  /// survives a restart and cannot be moved by the system clock.
  Duration get playtime => _playedBefore + _played.elapsed;
  final Stopwatch _played = Stopwatch();
  Duration _playedBefore = Duration.zero;

  /// Reads the autosave, then starts the game either way.
  Future<void> start() async {
    await loadFrom(SaveSlot.auto);
    _ready = true;
    _played.start();
    drill.start();
    _syncChargeLoop();
    _autosave = Timer.periodic(
      autosaveEvery,
      (_) => unawaited(saveTo(SaveSlot.auto)),
    );
    notifyListeners();
  }

  /// Returns whether a save was there and could be read.
  ///
  /// A store that cannot be reached at all -- no permission, no plugin on this
  /// build -- is reported and stepped over. The game has to start either way:
  /// a broken save directory must cost the save, never the session.
  Future<bool> loadFrom(SaveSlot slot) async {
    final ({String contents, bool fromBackup})? held;
    try {
      held = await store.read(slot);
    } on Object catch (error) {
      debugPrint('save storage is unreachable: $error');
      _storageFault = '$error';
      return false;
    }
    if (held == null) return false;

    if (!_apply(held.contents)) {
      // The live file is unreadable. One generation back is kept exactly for
      // this, so try it before telling the player the slot is gone.
      final backup = await store.readBackup(slot);
      if (backup == null || !_apply(backup)) {
        debugPrint('save in ${slot.key} could not be read');
        await store.quarantine(slot);
        return false;
      }
      debugPrint('save in ${slot.key} was read from its backup');
    }
    _applyDrillRate();
    _syncChargeLoop();
    notifyListeners();
    return true;
  }

  /// Returns whether the text was a save this build can read.
  bool _apply(String raw) {
    try {
      final document = codec.decode(raw);
      final run = document.sections['run'];
      if (run is! Map) throw const SaveFormatException('no run section');
      sim.readJson(Map<String, Object?>.from(run));

      final session = document.sections['session'];
      _playedBefore = Duration(
        milliseconds: session is Map && session['playedMs'] is int
            ? session['playedMs'] as int
            : 0,
      );
      _played.reset();
      return true;
    } on SaveFormatException catch (error) {
      debugPrint('$error');
      return false;
    }
  }

  /// Returns whether the save actually reached the disk.
  ///
  /// A failure here is reported rather than swallowed: an interface that says
  /// "saved" over a write that never happened is worse than one that says
  /// nothing, because the player stops looking for the problem.
  Future<bool> saveTo(SaveSlot slot) {
    // Queued behind whatever is already writing rather than dropped: a manual
    // save the player asked for must not be swallowed because the autosave
    // happened to fire.
    final writing = (_writing ?? Future<void>.value()).then(
      (_) => _writeTo(slot),
    );
    _writing = writing;
    return writing;
  }

  Future<bool> _writeTo(SaveSlot slot) async {
    final now = DateTime.now();
    final document = SaveDocument(
      version: codec.currentVersion,
      sections: {
        // Read by the slot list without decoding the run, so the menu can
        // describe a save it is not about to start.
        // The headline, duplicated out of the run on purpose: the slot list
        // reads this and nothing else, so browsing saves never decodes a run
        // it is not about to start. Written from the same state in the same
        // call, so the two cannot drift apart.
        'meta': {
          'savedAt': now.toIso8601String(),
          'depth': sim.layer.value + 1,
          'drills': sim.drills.value,
          'drillPower': sim.drillPowerLevel.value,
          'restarts': sim.restarts.value,
          'playedMs': playtime.inMilliseconds,
          'stock': sim.stock.toJson(),
        },
        'run': sim.toJson(),
        'session': {'playedMs': playtime.inMilliseconds},
      },
    );
    try {
      await store.write(slot, codec.encode(document));
    } on Object catch (error) {
      debugPrint('save could not be written: $error');
      _storageFault = '$error';
      notifyListeners();
      return false;
    }
    _storageFault = null;
    if (slot == SaveSlot.auto) _lastSavedAt = now;
    notifyListeners();
    return true;
  }

  /// The last thing the save store failed with, or null if it is working.
  ///
  /// Surfaced so the menu can say why a slot stayed empty instead of leaving
  /// the player to guess.
  String? get storageFault => _storageFault;
  String? _storageFault;

  Future<bool> deleteSlot(SaveSlot slot) async {
    try {
      await store.delete(slot);
    } on Object catch (error) {
      debugPrint('save could not be deleted: $error');
      _storageFault = '$error';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
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

  /// Whether the window is not being drawn at all.
  bool _hidden = false;

  /// The most floats alive at once.
  ///
  /// A safety net rather than a design choice: bursts (forcing plus echoes,
  /// or any future faster tick) must degrade to dropping the oldest number,
  /// never to an unbounded list.
  static const int _maxFloats = 12;

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
      // The forced cycle is over. Another one only starts if the player is
      // still pressing and the gauge can pay for it up front.
      if (sim.forcing.value && !(_gripHeld && sim.renewForcing())) {
        sim.endForcing();
      }
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
    // Nothing wakes while paused; resume() reruns this itself.
    if (_paused) return;
    if (sim.chargeFull) {
      if (chargeLoop.isRunning) chargeLoop.stop();
    } else if (!chargeLoop.isRunning) {
      chargeLoop.start();
    }
  }

  void _reportCycle(CycleOutcome outcome) {
    // No frames, no audience: recording effects while hidden only builds the
    // backlog that would all play at once on refocus.
    if (_hidden) return;
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
    if (!outcome.crystalsGained.isZero) {
      _addFloat(
        text: '+${outcome.crystalsGained.toString(NumberStyle.compact)}',
        color: 0xFF9FD8FF,
        left: 44,
        top: 138,
        size: 15,
      );
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
    if (floats.length >= _maxFloats) floats.removeAt(0);
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
    if (_paused) return;
    _gripHeld = true;
    _engageForcing();
  }

  /// Lets go of the grip. The cycle already paid for runs on to its end.
  void stopForcing() {
    _gripHeld = false;
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
    _played.stop();
    _autosave?.cancel();
    _lifecycle.dispose();
    _forcingWatch();
    drill.dispose();
    chargeLoop.dispose();
    criticalFlashes.dispose();
    breakFlashes.dispose();
    super.dispose();
  }
}
