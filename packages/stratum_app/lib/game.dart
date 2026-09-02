import 'dart:async';

import 'save_slot.dart';

import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'floating_number.dart';
import 'notice.dart';
import 'save_store.dart';
import 'ui/float_cue.dart';

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
      scheduler: TickScheduler(
        rate: TickRate(
          _energyIntervalOf(PrototypeSimulation.baseEnergySeconds),
        ),
      ),
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

  /// The save chain lives in the core, where each step is pinned by a
  /// test; the app only picks it up.
  static final SaveCodec codec = SaveCodec(
    currentVersion: stratumSaveVersion,
    migrations: stratumSaveMigrations,
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

  // ------------------------------------------------------- clock breach

  /// How far back the wall clock may sit behind the save's last observed
  /// moment before it counts as tampering. NTP nudges move a clock by
  /// seconds; a player moves it by hours.
  static const Duration clockRewindTolerance = Duration(minutes: 2);

  /// When the simulation is whole again: the save's own last-observed
  /// moment. Non-null while the breach overlay holds the game.
  int? get breachUntilMs => _breachUntilMs;
  int? _breachUntilMs;
  Timer? _breachTimer;

  /// True when the wall clock sits behind what the save has already lived.
  /// The acknowledged clock never runs backwards, so the only way to get
  /// here is winding the system clock forward, banking that time, and
  /// winding it back.
  bool _clockBreached() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now + clockRewindTolerance.inMilliseconds < sim.lastWallMs;
  }

  /// Halts everything behind an unclosable overlay until the wall clock
  /// catches up with the save. No absence is stamped and none will be
  /// settled: time spent in the breach pays nothing.
  void _enterBreach() {
    if (_breachUntilMs != null) return;
    _breachUntilMs = sim.lastWallMs;
    drill.stop();
    energyLoop.stop();
    _breachTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_clockBreached()) {
        _exitBreach();
      } else {
        // The countdown on the overlay reads this notifier.
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _exitBreach() {
    if (_breachUntilMs == null) return;
    _breachTimer?.cancel();
    _breachTimer = null;
    _breachUntilMs = null;
    // The clock has caught up to the exact moment the save had already
    // lived, so the gap observed here is nil: the wait pays nothing.
    sim.observeWall(DateTime.now().millisecondsSinceEpoch);
    if (_ready && !_paused) {
      drill.start();
      _syncEnergyLoop();
    }
    notifyListeners();
  }

  /// Checks the clock and holds the game if it has been wound back.
  /// Returns whether the game is (now) held.
  bool _guardClock() {
    if (_clockBreached()) {
      _enterBreach();
      return true;
    }
    if (_breachUntilMs != null) _exitBreach();
    return false;
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
    _stampCycleStart();
    _ready = true;
    _played.start();
    if (!_guardClock()) {
      drill.start();
      _syncEnergyLoop();
    }
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
    _stampCycleStart();
    if (sim.fundingWasReset) {
      sim.fundingWasReset = false;
      _announce(
        'баланс змінився — розподіліть транші фінансування заново',
        NoticeKind.info,
      );
    }
    _muteGains = false;
    // A clean slot lifts a standing breach; a tampered one raises it. The
    // engines re-arm through the exit path, not here.
    _guardClock();
    if (_breachUntilMs == null) _syncEnergyLoop();
    notifyListeners();
    return true;
  }

  /// The drift formula needs to know when the cycle began -- on the
  /// acknowledged clock. A fresh game and a save from before the clock
  /// existed carry no stamp, so one is taken here; the core stays free of
  /// DateTime.
  void _stampCycleStart() {
    final now = DateTime.now().millisecondsSinceEpoch;
    sim.observeWall(now);
    if (sim.cycleStartMs.value >= 0) return;
    sim.cycleStartMs.value = sim.seenNow(now);
  }

  /// Returns whether the text was a save this build can read.
  bool _apply(String raw) {
    try {
      final document = codec.decode(raw);
      final run = document.sections['run'];
      if (run is! Map) throw const SaveFormatException('no run section');
      sim.readJson(Map<String, Object?>.from(run));
      // A board restored from disk is the dot's news, not toast news: only
      // a request that ARRIVES in this session gets a corner card.
      _announcedRequests
        ..clear()
        ..addAll(sim.requests);

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
    } on Object catch (error) {
      // Anything the read throws -- a malformed document, a corrupt value
      // deep inside a section -- is the same verdict: this file does not
      // load, try the backup, then quarantine. Catching only the codec's
      // own exception let a value-corrupt save escape that path.
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
    // NOTHING writes during a clock breach -- not the autosave timer, not
    // the lifecycle hooks, not a manual slot save. The game is frozen, so
    // there is no progress to lose; and a slot written now would carry the
    // future-dated stamp into itself, spreading the breach to the one place
    // the player can escape to.
    if (_breachUntilMs != null) return Future.value(false);
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
    // The save's own write moment IS the last-activity stamp the breach
    // detector trusts, so bank it right here: `clock.last` in the run and
    // `meta.savedAt` leave this method telling the same story. observeWall
    // is monotonic, so a rewound clock cannot lower the stamp on the way.
    sim.observeWall(now.millisecondsSinceEpoch);
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
          // UTC on purpose: an ISO string in local time shifts with the
          // machine's timezone, which is one more clock a player can turn.
          // (clock.last needs no such care -- epoch ms has no timezone.)
          'savedAt': now.toUtc().toIso8601String(),
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
  String? get storageFault =>
      _storageFault ??
      (store.listFaults.isEmpty ? null : store.listFaults.values.first);
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
  /// The supply level sets this, so it is derived rather than fixed: a
  /// faster pack is a shorter wait between points, and the engine is re-armed
  /// whenever the level moves.
  /// The regen cadence, from the core's own figure -- which already
  /// carries the supply track and the auto-hands penalty.
  static Duration _energyIntervalOf(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

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
  ///
  /// Clamped to the core's absence cap: a week away pays -- and shows --
  /// two days. The acknowledged clock is banked here too, so drift credits
  /// the same clamped span the payout does.
  void _settleAbsence(Duration away) {
    if (away <= Duration.zero) return;
    const cap = Duration(milliseconds: PrototypeSimulation.absenceCapMs);
    if (away > cap) away = cap;
    // One core call: income and the craft lines interleave slice by
    // slice over the shared stock, so a line that feeds another keeps
    // feeding it through the absence -- and no duplicate or boost luck
    // is rolled while nobody watches.
    _muteGains = true;
    final gain = sim.settleAbsence(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      seconds: away.inMicroseconds / 1e6,
      energyPerSecond: energyPerSecond,
      cycleSeconds: cycleSeconds,
    );
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
          live.revision++;
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
    // The mine announces what the mine dug. Crafted goods land in the
    // same stockpile, but their story is told on the craft screen -- a
    // bench delivery popping up over the rock read as phantom digging.
    if (craftRecipeOf(id) != null) return;
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

  /// Whether income cards have an audience.
  ///
  /// The shell keeps this pointed at the mine screen: income belongs to the
  /// scene where it visibly happens, and on any other screen the cards were
  /// noise laid over unrelated reading. Saves and errors are not gated --
  /// those matter wherever the player is.
  /// Whether the mine itself is on screen.
  ///
  /// Everything the mine says -- its gain cards, its floating numbers -- is
  /// furniture of that screen, and the simulation behind it keeps running on
  /// every other one. Without this flag the effects queue fills while nobody
  /// is watching and pours out on the way back: a dozen crits landing in one
  /// frame, which is what the window's own onHide/onShow pair already exists
  /// to prevent. Same reasoning, one level up.
  bool _watched = true;

  void setWatched(bool watched) {
    if (_watched == watched) return;
    _watched = watched;
    if (!watched) {
      // Leaving the mine sweeps its cards along: a stale streak hanging over
      // the next screen is exactly what this flag exists to prevent.
      for (final notice in List.of(notices)) {
        if (notice.kind == NoticeKind.gain) _drop(notice);
      }
      // And its floats, which have no animation to retire them off-screen.
      floats.clear();
      notifyListeners();
    }
  }

  void _announceGain(ResourceId id, BigDouble amount) {
    if (!_watched) return;
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

  /// Bumped whenever the scene should flash for a broken layer.
  final ValueNotifier<int> breakFlashes = ValueNotifier(0);

  /// Bumped for every blow the face takes -- manual or the drill's own -- so
  /// the current layer can shudder under it.
  final ValueNotifier<int> hitShakes = ValueNotifier(0);

  /// The two cadences the yield rate is built from. They live here because
  /// the engines do; the core is handed them rather than owning a clock.
  double get cycleSeconds => drill.rate.interval.inMicroseconds / 1e6;

  double get energyPerSecond => sim.energyPerRegen / sim.energySeconds;

  /// The requests the player has already laid eyes on. Attention state,
  /// not progress -- it lives here rather than in the save, and a reload
  /// lighting the dot once is the honest outcome: the board IS news again.
  final Set<TradeRequest> _seenRequests = {};

  /// Whether the board holds a request the player has not seen. This is
  /// what the trade tab's dot answers -- "a courier came", not "you can
  /// afford something", which at these odds would burn the dot always-on.
  bool get hasUnseenRequests =>
      sim.requests.any((request) => !_seenRequests.contains(request));

  /// Requests already toasted. Kept apart from [_seenRequests]: a toast in
  /// the corner is not the player LOOKING at the board, so the dot stays
  /// lit until they actually visit it.
  final Set<TradeRequest> _announcedRequests = {};

  void _announceNewRequests() {
    _announcedRequests.retainAll(sim.requests);
    for (final request in sim.requests) {
      if (_announcedRequests.add(request)) {
        _announce(
          'новий запит · премія +${(request.premium * 100).round()}%',
          NoticeKind.info,
        );
      }
    }
  }

  /// Drill tracks that were affordable the last time the player LOOKED at
  /// the drills screen. Same discipline as the request board: a dot that
  /// answers "can you afford something" is always lit in an idle game and
  /// means nothing -- news is a track that BECAME affordable since then.
  final Set<String> _seenAffordableTracks = {};

  Iterable<String> _affordableTracks() sync* {
    // The rig itself is the drills screen's first purchase: it becoming
    // affordable is that screen's news.
    if (sim.canBuyRig) yield 'rig';
    for (final row in PrototypeSimulation.drillTable) {
      for (final part in DrillPart.values) {
        if (sim.canUpgradeDrill(row.id, part)) {
          yield '${row.id.name}.${part.name}';
        }
      }
    }
  }

  bool get hasNewDrillUpgrades => _affordableTracks().any(
    (track) => !_seenAffordableTracks.contains(track),
  );

  /// An automation that became affordable since the ladder was last
  /// looked at -- news, not capability, like every other dot.
  bool get hasNewAutomation => AutomationId.values.any(
    (id) =>
        sim.canUnlockAutomation(id) && !_seenAffordableAutomations.contains(id),
  );

  final Set<AutomationId> _seenAffordableAutomations = {};

  void markAutomationSeen() {
    _seenAffordableAutomations
      ..clear()
      ..addAll(AutomationId.values.where(sim.canUnlockAutomation));
  }

  /// The drills screen is open: snapshot what is affordable. A track that
  /// later dips below affordable and climbs back IS news again, which is
  /// why this replaces the set rather than adding to it.
  void markDrillUpgradesSeen() {
    _seenAffordableTracks
      ..clear()
      ..addAll(_affordableTracks());
  }

  /// A UI act changed sim state no stockpile signal reports (a tranche
  /// poured, a setting flipped): repaint whoever listens.
  void pokeListeners() => notifyListeners();

  /// An automation setting moved the regen cadence: re-arm the loop and
  /// repaint.
  void refreshEnergyLoop() {
    _syncEnergyLoop();
    notifyListeners();
  }

  /// The board is on screen: everything on it stops being news.
  void markRequestsSeen() {
    if (!hasUnseenRequests) return;
    _seenRequests.addAll(sim.requests);
    notifyListeners();
  }

  void _onDrillBatch(TickBatch batch) {
    if (_guardClock()) return;
    final wallNow = DateTime.now().millisecondsSinceEpoch;
    sim.observeWall(wallNow);
    sim.syncRequests(wallNow);
    sim.syncCraft(wallNow);
    // Quietly: replicated growth is continuous income, and a gain card
    // over the mine every batch would be pure noise.
    _muteGains = true;
    sim.syncReplicator(wallNow);
    _muteGains = false;
    // The automations run here, once a second, and the hands they owe
    // are thrown through the same path a finger uses.
    final autoStrikes = sim.syncAutomations(wallNow);
    for (var i = 0; i < autoStrikes; i++) {
      strike();
    }
    _seenRequests.retainAll(sim.requests);
    _announceNewRequests();
    for (var i = 0; i < batch.ticks; i++) {
      final outcome = sim.tick();
      // No rig yet: the engine ticks through empty, and nothing shakes.
      if (identical(outcome, CycleOutcome.none)) continue;
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
    // The pack's cadence is a level away from changing, so the engine is
    // re-armed here rather than at every call site that might have moved it.
    final wanted = _energyIntervalOf(sim.energySeconds);
    if (energyLoop.rate.interval != wanted) {
      energyLoop.rate = TickRate(wanted);
    }
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
    // float is for the strike's crit -- the same drama whichever lane threw
    // the blow.
    if (outcome.critical) _reportCrit();
    if (outcome.thickLayersBroken > 0) _addFloat(FloatCue.thickLayer());
    if (outcome.layersBroken > 0) {
      breakFlashes.value = breakFlashes.value + 1;
    }
    if (outcome.echoes > 0) _addFloat(FloatCue.echo);
  }

  /// Puts a cue over the face; the words and the spot are the cue's own
  /// business, this only keeps the queue.
  void _addFloat(FloatCue cue) {
    // Nobody to see it, and nothing to retire it: an unwatched float is a
    // float that waits for the player to come back and then arrives late.
    if (!_watched) return;
    if (floats.length >= _maxFloats) floats.removeAt(0);
    floats.add(
      FloatingNumber(
        id: _nextFloatId++,
        text: cue.text,
        color: cue.color,
        left: cue.left,
        top: cue.top,
        size: cue.size,
      ),
    );
  }

  void retireFloat(int id) {
    floats.removeWhere((f) => f.id == id);
  }

  /// The strike's crit, said the same way for both lanes: one quiet word
  /// over the face.
  ///
  /// No wash of colour behind it. A crit is a common event -- one strike in
  /// twenty, and the hand throws ten a second -- so a full-scene flash was
  /// firing several times a second over the thing the player is watching.
  void _reportCrit() {
    if (_hidden || _background) return;
    _addFloat(FloatCue.crit(hitShakes.value));
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
    if (outcome.critical) _reportCrit();
    if (outcome.layersBroken > 0) {
      breakFlashes.value = breakFlashes.value + 1;
    }
    // No gain announcements here: the stockpile watcher reports every income
    // once, and a second voice was double-counting the streaks.
    _syncEnergyLoop();
    notifyListeners();
  }

  /// Buys [levels] of an arm part. The energy loop is re-synced either way:
  /// the supply part moves both the gauge's ceiling and the engine's cadence.
  void upgradeArm(ArmPart part, {int levels = 1}) {
    if (sim.upgrade(part, levels: levels) == 0) return;
    _syncEnergyLoop();
    notifyListeners();
  }

  /// Buys levels on one of a drill's three tracks.
  void upgradeDrill(DrillId id, DrillPart part, {int levels = 1}) {
    if (sim.upgradeDrill(id, part, levels: levels) == 0) return;
    notifyListeners();
  }

  /// Rebuilds a part into its next mark. Returns the mark it now carries, so
  /// the caller can show what just happened; null when it was not ready.
  int? evolveArm(ArmPart part) {
    final mark = sim.evolve(part);
    if (mark == null) return null;
    _syncEnergyLoop();
    notifyListeners();
    return mark;
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
    _breachTimer?.cancel();
    _lifecycle.dispose();
    drill.dispose();
    energyLoop.dispose();
    breakFlashes.dispose();
    hitShakes.dispose();
    super.dispose();
  }
}
