/// How many logical ticks happen per stretch of real time.
///
/// [ticksPerFire] expresses a pace faster than the interval without shortening
/// the interval itself. The engine imposes no lower bound on [interval]: the
/// rule "one second floor, past that upgrades buy actions per tick" belongs to
/// the game's balance config, which simply never hands a smaller value down.
class TickRate {
  TickRate(this.interval, {this.ticksPerFire = 1}) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'interval',
        'tick interval must be positive',
      );
    }
    if (ticksPerFire < 1) {
      throw ArgumentError.value(
        ticksPerFire,
        'ticksPerFire',
        'a fire must produce at least one tick',
      );
    }
  }

  final Duration interval;
  final int ticksPerFire;

  @override
  String toString() => '$ticksPerFire tick(s) / ${interval.inMilliseconds}ms';
}

class TickBatch {
  const TickBatch({
    required this.ticks,
    required this.consumed,
    required this.overflow,
  });

  static const TickBatch empty = TickBatch(
    ticks: 0,
    consumed: Duration.zero,
    overflow: Duration.zero,
  );

  final int ticks;

  /// How much real time those ticks accounted for.
  final Duration consumed;

  /// Real time dropped by the catch-up cap; zero when the cap did not bite.
  ///
  /// Whatever lands here the engine will never replay. It is meant for the
  /// offline calculation, which resolves it with a single formula over the
  /// elapsed span rather than a step-by-step simulation.
  final Duration overflow;

  bool get isEmpty => ticks == 0;

  @override
  String toString() =>
      'TickBatch(ticks: $ticks, consumed: $consumed, overflow: $overflow)';
}

/// The pure half of the tick engine: counts ticks without knowing about clocks.
///
/// Nothing here is asynchronous and there is no time source — time is handed in
/// from outside. That is why replaying a day of play in a test costs
/// milliseconds and needs neither an emulator nor fake timers.
///
/// It does not execute ticks. It returns how many are due and the caller runs
/// the loop, which leaves the game free to collapse a run of ticks analytically
/// instead of stepping through them one by one.
class TickScheduler {
  TickScheduler({
    required TickRate rate,
    this.maxTicksPerAdvance = defaultMaxTicksPerAdvance,
  }) {
    if (maxTicksPerAdvance < 1) {
      throw ArgumentError.value(
        maxTicksPerAdvance,
        'maxTicksPerAdvance',
        'the catch-up cap must be positive',
      );
    }
    _rate = rate;
  }

  /// Counted in ticks rather than seconds because executed ticks are what
  /// costs. Without a cap a long pause builds a debt the simulation can never
  /// repay and every following frame gets worse — the classic spiral of death.
  static const int defaultMaxTicksPerAdvance = 64;

  final int maxTicksPerAdvance;

  late TickRate _rate;
  Duration _pending = Duration.zero;

  TickRate get rate => _rate;

  /// Changing the rate carries the accumulator across as a *fraction of an
  /// interval* rather than as seconds.
  ///
  /// A tick already three quarters served stays three quarters served when the
  /// interval halves: the player who has been waiting does not get sent back to
  /// the start of the wait. Scaling instead of keeping the seconds is what
  /// closes the obvious exploit -- banking time on a slow rate and cashing it
  /// in as a burst of ticks on a fast one buys nothing, because the banked
  /// amount is measured in ticks, and that number does not change.
  set rate(TickRate value) {
    if (_pending > Duration.zero) {
      final served = _pending.inMicroseconds / _rate.interval.inMicroseconds;
      _pending = Duration(
        microseconds: (served * value.interval.inMicroseconds).round(),
      );
    }
    _rate = value;
  }

  /// Time accumulated but not yet played out.
  Duration get pending => _pending;

  void reset() => _pending = Duration.zero;

  /// Moves time forward and reports how many ticks that caused.
  ///
  /// Accounting invariant:
  /// `pending_before + elapsed == consumed + overflow + pending_after`.
  /// No millisecond appears or disappears.
  TickBatch advance(Duration elapsed) {
    if (elapsed < Duration.zero) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'time does not run backwards: the engine measures a monotonic clock',
      );
    }

    _pending += elapsed;

    final possibleFires =
        _pending.inMicroseconds ~/ _rate.interval.inMicroseconds;
    if (possibleFires == 0) return TickBatch.empty;

    final maxFires = maxTicksPerAdvance ~/ _rate.ticksPerFire;
    final fires = possibleFires < maxFires ? possibleFires : maxFires;

    final consumed = _rate.interval * fires;
    _pending -= consumed;

    // The cap bit only if we genuinely failed to catch up. Then the rest goes
    // out to the caller; holding it inside would just defer the same debt.
    var overflow = Duration.zero;
    if (fires < possibleFires) {
      overflow = _pending;
      _pending = Duration.zero;
    }

    return TickBatch(
      ticks: fires * _rate.ticksPerFire,
      consumed: consumed,
      overflow: overflow,
    );
  }
}
