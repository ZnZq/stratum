import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'save_store.dart';

/// A transient report: something happened, said once, gone in seconds.
enum NoticeKind { success, error, info, gain }

class Notice {
  Notice({
    required this.id,
    required this.text,
    required this.kind,
    this.key,
    this.resource,
  });

  final int id;

  /// Mutable on purpose: a keyed notice is updated in place while its kin
  /// keep arriving, instead of stacking a card per event.
  String text;

  final NoticeKind kind;

  /// Coalescing identity: a new report with the same key refreshes this card
  /// and its lifetime rather than adding another.
  final String? key;

  /// For [NoticeKind.gain]: which resource the card is about.
  final ResourceId? resource;

  /// Set shortly before removal, so the card can fade instead of popping.
  bool leaving = false;

  Timer? life;
}

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
/// mining; energy regenerates on its own slower loop that stops itself once
/// the gauge is full and resumes when the player spends some. Stopping the
/// drill loop for a full gauge would freeze the mining too.
class Game extends ChangeNotifier {
  Game({SaveStore? store}) : store = store ?? SaveStore() {
    drill = TickEngine(
      scheduler: TickScheduler(rate: baseRate),
      onBatch: _onDrillBatch,
    );
    energyLoop = TickEngine(
      scheduler: TickScheduler(rate: energyRate),
      onBatch: _onEnergyBatch,
    );

    // Every income, whatever produced it -- a tick, a strike, a break
    // bonus, a thick layer, a mechanic not written yet -- lands in the
    // stockpile, so the stockpile is the one honest place to report income
    // from. Signals fire once per batch, so a cycle's many additions arrive
    // as one delta.
    for (final id in ResourceId.values) {
      _seenStock[id] = sim.stock.amount(id);
      _stockWatches.add(sim.stock.signal(id).listen(() => _onStockChange(id)));
    }

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
  static final SaveCodec codec = SaveCodec(
    currentVersion: 3,
    migrations: [
      // v2 -> v3: forcing is gone; its charge gauge became energy.
      SaveMigration(
        fromVersion: 2,
        apply: (sections) {
          final run = sections['run'];
          if (run is! Map) return sections;
          final out = Map<String, Object?>.from(run);
          if (out.containsKey('charge')) {
            out['energy'] = out.remove('charge');
          }
          return {...sections, 'run': out};
        },
      ),
      // v1 -> v2: the always-drop stopped being "ore" and became regolith,
      // with the chance ores taking the ore name for themselves.
      SaveMigration(
        fromVersion: 1,
        apply: (sections) {
          Map<String, Object?>? renamed(Object? holder) {
            if (holder is! Map) return null;
            final stock = holder['stock'];
            if (stock is! Map) return null;
            final out = Map<String, Object?>.from(stock);
            if (out.containsKey('ore')) {
              out['regolith'] = out.remove('ore');
            }
            return {...Map<String, Object?>.from(holder), 'stock': out};
          }

          return {
            ...sections,
            'run': ?renamed(sections['run']),
            'meta': ?renamed(sections['meta']),
          };
        },
      ),
    ],
  );

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

  /// Background mode: the simulation runs at full speed, the presentation
  /// does not.
  ///
  /// The opposite trade to pause. Pause keeps the picture and stops the game;
  /// this keeps the game and drops the picture -- for leaving the app open
  /// without paying for sixty frames a second of dust and flutes.
  bool get background => _background;
  bool _background = false;

  void setBackground(bool value) {
    if (_background == value) return;
    _background = value;
    if (value) {
      // Background means "run while I am away", so a paused game resumes:
      // holding both at once would show a dark screen claiming to mine.
      if (_paused) resume();
      floats.clear();
      _backgroundAt = DateTime.now();
    } else {
      _backgroundAt = null;
    }
    notifyListeners();
  }

  /// Freezes the whole heartbeat: drilling and energy.
  ///
  /// Both engines stop through [TickEngine.stop], which banks the time already
  /// served -- so the cycle ring and the charge sweep freeze mid-fill and
  /// carry on from the same spot on resume, rather than snapping back.
  void pause() {
    if (_paused || !_ready) return;
    _paused = true;
    _pausedAt = DateTime.now();
    drill.stop();
    energyLoop.stop();
    // A pause is a natural walking-away point, so bank the run while at it.
    unawaited(saveTo(SaveSlot.auto));
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    // A pause is an absence like any other: the engines held still, so the
    // span earns at offline pace rather than being simply lost.
    if (_pausedAt != null) {
      _settleAbsence(DateTime.now().difference(_pausedAt!));
      _pausedAt = null;
    }
    drill.start();
    _syncEnergyLoop();
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
    final restored = await loadFrom(SaveSlot.auto);
    // Settled only here, never on a manual load: loading a slot restores a
    // state, and paying interest on how long the file sat on disk would make
    // reloading old saves a mint.
    if (restored && _restoredAt != null) {
      _settleAbsence(DateTime.now().difference(_restoredAt!));
    }
    _ready = true;
    _played.start();
    drill.start();
    _syncEnergyLoop();
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
      _announce('сховище недоступне', NoticeKind.error);
      return false;
    }
    if (held == null) return false;

    _muteGains = true;
    if (!_apply(held.contents)) {
      // The live file is unreadable. One generation back is kept exactly for
      // this, so try it before telling the player the slot is gone.
      final backup = await store.readBackup(slot);
      if (backup == null || !_apply(backup)) {
        debugPrint('save in ${slot.key} could not be read');
        await store.quarantine(slot);
        _announce('сейв не читається — відкладено', NoticeKind.error);
        _muteGains = false;
        return false;
      }
      debugPrint('save in ${slot.key} was read from its backup');
      _announce('відновлено з резервної копії', NoticeKind.info);
    } else {
      _announce(
        slot == SaveSlot.auto
            ? 'прогрес відновлено'
            : 'завантажено: ${slot.label}',
        NoticeKind.success,
      );
    }
    _muteGains = false;
    _syncEnergyLoop();
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

      final meta = document.sections['meta'];
      _restoredAt = meta is Map
          ? DateTime.tryParse('${meta['savedAt']}')
          : null;

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
      _announce('збереження не вдалося', NoticeKind.error);
      notifyListeners();
      return false;
    }
    _storageFault = null;
    if (slot == SaveSlot.auto) _lastSavedAt = now;
    // An autosave nobody can see expires unseen; skipping it while hidden
    // would be more code for the same silence.
    _announce(
      slot == SaveSlot.auto ? 'автозбереження' : 'збережено: ${slot.label}',
      slot == SaveSlot.auto ? NoticeKind.info : NoticeKind.success,
    );
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
      _announce('не вдалося стерти слот', NoticeKind.error);
      notifyListeners();
      return false;
    }
    _announce('стерто: ${slot.label}', NoticeKind.info);
    notifyListeners();
    return true;
  }

  static final TickRate baseRate = TickRate(const Duration(seconds: 4));

  /// One point of charge every two seconds, on its own loop rather than
  /// borrowing the drill's heartbeat. The meter above the readout is driven
  /// by this engine, so what the player watches filling is the real interval.
  static final TickRate energyRate = TickRate(const Duration(seconds: 2));

  final PrototypeSimulation sim = PrototypeSimulation();

  late final TickEngine drill;
  late final TickEngine energyLoop;

  final List<FloatingNumber> floats = [];
  int _nextFloatId = 0;

  /// The last absence worth telling the player about, or null.
  ///
  /// Set by [_settleAbsence] when the span crosses [offlineNoticeThreshold];
  /// shorter gaps settle silently. The window clears it on dismissal.
  ({OfflineGain gain, Duration away})? get offlineArrival => _offlineArrival;
  ({OfflineGain gain, Duration away})? _offlineArrival;

  /// Below this the settlement happens without a word: a minute's absence is
  /// a distraction, not an event.
  static const Duration offlineNoticeThreshold = Duration(minutes: 1);

  void dismissOffline() {
    _offlineArrival = null;
    notifyListeners();
  }

  /// Pays out an absence and decides whether it deserves a window.
  void _settleAbsence(Duration away) {
    if (away <= Duration.zero) return;
    final cycles = away.inMicroseconds ~/ baseRate.interval.inMicroseconds;
    _muteGains = true;
    final gain = sim.claimOffline(cycles: cycles);
    _muteGains = false;
    if (gain.isEmpty) return;
    if (away >= offlineNoticeThreshold) {
      _offlineArrival = (gain: gain, away: away);
    }
    notifyListeners();
  }

  /// When the save being applied was written, for the launch settlement.
  DateTime? _restoredAt;

  /// When the pause began, for the overlay's clock and the settlement.
  DateTime? get pausedAt => _pausedAt;
  DateTime? _pausedAt;

  /// When background mode began. Display only: the engines never stopped, so
  /// there is nothing to settle.
  DateTime? get backgroundAt => _backgroundAt;
  DateTime? _backgroundAt;

  /// Live toasts, oldest first. The UI renders them; this side owns their
  /// lifetime, because saves also happen with no UI in sight (autosave,
  /// losing focus) and the report must not depend on who is looking.
  final List<Notice> notices = [];
  int _nextNoticeId = 0;

  static const Duration _noticeLife = Duration(milliseconds: 2800);
  static const Duration _noticeFade = Duration(milliseconds: 300);

  void _announce(
    String text,
    NoticeKind kind, {
    String? key,
    ResourceId? resource,
  }) {
    if (_disposed) return;

    if (key != null) {
      for (final live in notices) {
        if (live.key == key && !live.leaving) {
          live.text = text;
          _armLife(live);
          notifyListeners();
          return;
        }
      }
    }

    final notice = Notice(
      id: _nextNoticeId++,
      text: text,
      kind: kind,
      key: key,
      resource: resource,
    );
    notices.add(notice);
    // A burst degrades to dropping the oldest card, never to a tower.
    if (notices.length > 6) _drop(notices.first);
    _armLife(notice);
    notifyListeners();
  }

  void _armLife(Notice notice) {
    notice.life?.cancel();
    notice.life = Timer(_noticeLife, () {
      if (_disposed || !notices.contains(notice)) return;
      notice.leaving = true;
      notifyListeners();
      notice.life = Timer(_noticeFade, () {
        if (_disposed) return;
        _drop(notice);
        notifyListeners();
      });
    });
  }

  void _drop(Notice notice) {
    notice.life?.cancel();
    notices.remove(notice);
    if (notice.key != null) _gainStreak.remove(notice.key);
  }

  final Map<ResourceId, BigDouble> _seenStock = {};
  final List<Unsubscribe> _stockWatches = [];

  /// Announcements go quiet while a save is being applied or an absence is
  /// being settled: those deltas are not mining, and the offline window
  /// already reports the settlement itself.
  bool _muteGains = false;

  void _onStockChange(ResourceId id) {
    final now = sim.stock.amount(id);
    final before = _seenStock[id] ?? BigDouble.zero;
    _seenStock[id] = now;
    if (_muteGains || _hidden || _background || !_ready) return;
    final delta = now - before;
    if (!(delta > BigDouble.zero)) return;
    _announceGain(id, delta);
  }

  /// What each live gain card has accumulated, keyed like its notice.
  ///
  /// The card shows the run of the current digging spree, not one blow: while
  /// the player holds to dig, the same card keeps counting up and quoting the
  /// stockpile total beside it.
  final Map<String, BigDouble> _gainStreak = {};

  void _announceGain(ResourceId id, BigDouble amount) {
    if (amount.isZero) return;
    final key = 'gain.${id.name}';
    final streak = (_gainStreak[key] ?? BigDouble.zero) + amount;
    _gainStreak[key] = streak;
    _announce(
      '+${streak.toString(NumberStyle.compact)}'
      '\n${sim.stock.amount(id).toString(NumberStyle.compact)}',
      NoticeKind.gain,
      key: key,
      resource: id,
    );
  }

  bool _disposed = false;

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

  /// Bumped for every blow the face takes -- manual or the drill's own -- so
  /// the current layer can shudder under it.
  final ValueNotifier<int> hitShakes = ValueNotifier(0);

  /// The heartbeat as it currently stands.
  String get tickInterval => secondsLabel(drill.rate.interval);

  /// How long one point of energy takes, for the gauge to say so out loud.
  static String get energyInterval => secondsLabel(energyRate.interval);

  static String secondsLabel(Duration interval) =>
      '${(interval.inMilliseconds / 1000).toStringAsFixed(1)} с';

  void _onDrillBatch(TickBatch batch) {
    for (var i = 0; i < batch.ticks; i++) {
      final outcome = sim.tick();
      // The drill's tick is a strike of its own: mine, then hit the face.
      hitShakes.value = hitShakes.value + 1;
      _reportCycle(outcome);
    }
    _syncEnergyLoop();
    notifyListeners();
  }

  void _onEnergyBatch(TickBatch batch) {
    for (var i = 0; i < batch.ticks; i++) {
      sim.regenerateEnergy();
    }
    if (sim.energyFull) energyLoop.stop();
    notifyListeners();
  }

  /// The energy loop sleeps while the gauge is full, so spending has to wake it.
  void _syncEnergyLoop() {
    // Nothing wakes while paused; resume() reruns this itself.
    if (_paused) return;
    if (sim.energyFull) {
      if (energyLoop.isRunning) energyLoop.stop();
    } else if (!energyLoop.isRunning) {
      energyLoop.start();
    }
  }

  void _reportCycle(CycleOutcome outcome) {
    // No frames, no audience: recording effects while hidden or in background
    // mode only builds the backlog that would all play at once on return.
    if (_hidden || _background) return;

    // Income reporting belongs to the stockpile watcher and its cards; the
    // floats keep only the drama.
    if (outcome.critical) {
      criticalFlashes.value = criticalFlashes.value + 1;
      _addFloat(
        text: 'КРИТ ×${sim.criticalMultiplier.round()}',
        color: 0xFFFFD782,
        left: 26 + (outcome.layersBroken * 17 % 120).toDouble(),
        top: 92 + (outcome.quantoniumGained * 11 % 30).toDouble(),
        size: 24,
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

  /// One manual blow at the face.
  ///
  /// The strike lands between ticks by design: it is the player's own damage,
  /// not a nudge to the engine.
  void strike() {
    if (!_ready || _paused) return;
    final outcome = sim.strike();
    if (!outcome.landed) return;
    hitShakes.value = hitShakes.value + 1;
    if (outcome.layersBroken > 0) {
      breakFlashes.value = breakFlashes.value + 1;
    }
    if (!_hidden && !_background) {
      _announceGain(ResourceId.regolith, outcome.regolithGained);
      for (final entry in outcome.oresGained.entries) {
        _announceGain(entry.key, entry.value);
      }
    }
    _syncEnergyLoop();
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

  void buyStrikeUpgrade() {
    sim.buyStrikeUpgrade();
    notifyListeners();
  }

  void buyEnergyCapUpgrade() {
    sim.buyEnergyCapUpgrade();
    _syncEnergyLoop();
    notifyListeners();
  }

  void buyEnergyRegenUpgrade() {
    sim.buyEnergyRegenUpgrade();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final unsubscribe in _stockWatches) {
      unsubscribe();
    }
    for (final notice in notices) {
      notice.life?.cancel();
    }
    _played.stop();
    _autosave?.cancel();
    _lifecycle.dispose();
    drill.dispose();
    energyLoop.dispose();
    criticalFlashes.dispose();
    breakFlashes.dispose();
    hitShakes.dispose();
    super.dispose();
  }
}
