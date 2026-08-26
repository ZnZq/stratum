/// A xorshift128+ sequence whose whole state fits in two integers.
///
/// `Random` from `dart:math` is unusable here for one decisive reason: its
/// internal state cannot be read back or restored. The state of a game's
/// randomness has to live in the save file, or a reloaded run replays different
/// rolls and no parity test can be reproduced.
class RandomStream {
  RandomStream._(this._s0, this._s1);

  /// Derives a starting state from a single seed.
  factory RandomStream.seeded(int seed) {
    // SplitMix64 spreads a small seed across all 64 bits, so neighbouring seeds
    // do not produce correlated sequences.
    final s0 = _splitMix64(seed);
    final s1 = _splitMix64(s0);
    return RandomStream._(s0, s1 == 0 && s0 == 0 ? _fallbackState : s1);
  }

  factory RandomStream.fromJson(List<int> state) {
    if (state.length != 2) {
      throw FormatException('a RandomStream state is two integers', state);
    }
    final s0 = state[0];
    final s1 = state[1];
    return RandomStream._(s0, s0 == 0 && s1 == 0 ? _fallbackState : s1);
  }

  /// An all-zero state is the one thing xorshift cannot climb out of.
  static const int _fallbackState = 0x2545F4914F6CDD1D;

  int _s0;
  int _s1;

  /// The raw 64-bit output. Overflow wraps, which is what the algorithm wants.
  int _nextRaw() {
    var s1 = _s0;
    final s0 = _s1;
    _s0 = s0;
    s1 ^= s1 << 23;
    _s1 = s1 ^ s0 ^ (s1 >>> 18) ^ (s0 >>> 5);
    return _s1 + s0;
  }

  /// A value in `[0, 1)`, built from the top 53 bits — the exact mantissa width
  /// of a double.
  double nextDouble() => (_nextRaw() >>> 11) * _doubleUnit;

  static const double _doubleUnit = 1.0 / (1 << 53);

  int nextInt(int max) {
    if (max < 1) {
      throw ArgumentError.value(max, 'max', 'the bound must be positive');
    }
    return (nextDouble() * max).floor();
  }

  double range(double min, double max) {
    if (max <= min) {
      throw ArgumentError.value(max, 'max', 'the range must be non-empty');
    }
    return min + nextDouble() * (max - min);
  }

  /// Rolls a probability.
  ///
  /// Always draws, whatever [probability] is. That is what keeps a sequence
  /// stable when a balance number moves: dropping a crit chance to zero must
  /// not shift every roll that comes after it.
  bool chance(double probability) {
    if (probability < 0 || probability > 1) {
      throw ArgumentError.value(
        probability,
        'probability',
        'a probability lives in [0, 1]',
      );
    }
    return nextDouble() < probability;
  }

  List<int> toJson() => [_s0, _s1];

  static int _splitMix64(int seed) {
    var z = seed + 0x9E3779B97F4A7C15;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }
}

/// Named independent streams derived from one master seed.
///
/// Every consumer — crit, echo, quantonium — draws from its own stream. With a
/// single shared stream, introducing one new roll anywhere in a tick shifts
/// every roll after it, which turns every parity test red and makes two balance
/// runs incomparable for reasons that have nothing to do with balance.
class RandomSource {
  RandomSource({required this.seed});

  RandomSource._restored(this.seed, Map<String, RandomStream> streams) {
    _streams.addAll(streams);
  }

  factory RandomSource.fromJson(Map<String, dynamic> json) {
    final seed = json['seed'];
    if (seed is! int) {
      throw FormatException('a RandomSource needs an integer seed', json);
    }

    final rawStreams = json['streams'];
    if (rawStreams is! Map) {
      throw FormatException('a RandomSource needs a streams map', json);
    }

    final streams = <String, RandomStream>{};
    rawStreams.forEach((name, state) {
      streams['$name'] = RandomStream.fromJson(
        (state as List).map((v) => v as int).toList(),
      );
    });

    return RandomSource._restored(seed, streams);
  }

  final int seed;

  final Map<String, RandomStream> _streams = {};

  /// The stream for [name], created on first use.
  ///
  /// A stream missing from a restored save starts exactly where a fresh source
  /// with the same master seed would put it, so adding a consumer never
  /// invalidates an existing save.
  RandomStream stream(String name) =>
      _streams.putIfAbsent(name, () => RandomStream.seeded(_deriveSeed(name)));

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'streams': {
      for (final entry in _streams.entries) entry.key: entry.value.toJson(),
    },
  };

  int _deriveSeed(String name) =>
      _fnv1a64(name) ^ RandomStream._splitMix64(seed);

  /// FNV-1a, written out rather than taken from `String.hashCode`, which Dart
  /// does not promise to keep stable across runs or SDK versions.
  static int _fnv1a64(String text) {
    var hash = 0xCBF29CE484222325;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001B3;
    }
    return hash;
  }
}
