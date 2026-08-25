import 'dart:math' as math;

import 'number_style.dart';

/// A number with an extended exponent: `mantissa × 10^exponent`.
///
/// Normalization invariant: the value is either exactly zero
/// (`mantissa == 0 && exponent == 0`) or `1 ≤ |mantissa| < 10`. The invariant is
/// what keeps equality and comparison trivial — without it `1e3` and `10e2`
/// would be one number in two shapes.
class BigDouble implements Comparable<BigDouble> {
  factory BigDouble(double mantissa, int exponent) =>
      _normalized(mantissa, exponent);

  factory BigDouble.fromNum(num value) => _normalized(value.toDouble(), 0);

  /// Builds from an ALREADY normalized pair, without computing anything.
  ///
  /// Needed where a number has to be `const`: normalization needs a logarithm,
  /// and a const context cannot compute. The invariant is on whoever writes the
  /// constant, so an assert guards it.
  const BigDouble.fromMantissaExponent(this.mantissa, this.exponent)
      : style = null,
        assert(
          mantissa == 0 ||
              (mantissa >= 1 && mantissa < 10) ||
              (mantissa <= -1 && mantissa > -10),
          'mantissa must be zero or within [1, 10) in magnitude',
        ),
        assert(mantissa != 0 || exponent == 0, 'zero has a canonical exponent');

  const BigDouble._raw(this.mantissa, this.exponent, [this.style]);

  final double mantissa;

  final int exponent;

  /// This number's own output style.
  ///
  /// Takes part in neither equality, comparison, nor serialization: it is
  /// presentation, not value.
  final NumberStyle? style;

  BigDouble withStyle(NumberStyle? style) =>
      BigDouble._raw(mantissa, exponent, style);

  BigDouble _styled(NumberStyle? style) => identical(style, this.style)
      ? this
      : BigDouble._raw(mantissa, exponent, style);

  /// From break_infinity.js (`EXP_LIMIT`), for parity with the reference
  /// implementations of the genre.
  static const int expLimit = 9000000000000000;

  /// How many significant digits the mantissa carries.
  ///
  /// When two addends' exponents differ by more than this, the smaller one
  /// cannot influence a single bit of the result, so addition may drop it.
  /// From break_infinity.js (`MAX_SIGNIFICANT_DIGITS`).
  static const int maxSignificantDigits = 17;

  /// Default RELATIVE tolerance for comparisons, from break_infinity.js
  /// (`ROUND_TOLERANCE`).
  ///
  /// Game gates — "can I afford this", "is quantonium past the threshold" — must
  /// use the tolerant comparisons: two ways of computing the same number drift
  /// in the last bits, and a strict comparison then lies to the player.
  static const double roundTolerance = 1e-10;

  /// Whether to throw on invalid input instead of saturating the value.
  ///
  /// On wherever asserts are on (debug and tests), off in release. The
  /// trade-off: during development a poisoned value must fail where it is born,
  /// or it spreads through the state and surfaces in a save file an hour later;
  /// for a player the session matters more than purity, so there the value
  /// saturates and the fact goes to [onDomainError].
  static bool strictMode = _assertsEnabled();

  /// Where to report a substituted value in non-strict mode. `null` is silence.
  static void Function(String message)? onDomainError;

  static bool _assertsEnabled() {
    // `assert` is stripped in release, so the side effect only lands in debug.
    // This is the only way to learn the mode without importing
    // flutter/foundation.
    var enabled = false;
    assert(enabled = true);
    return enabled;
  }

  static BigDouble _domainError(String message, BigDouble fallback) {
    if (strictMode) throw ArgumentError(message);
    onDomainError?.call(message);
    return fallback;
  }

  static const BigDouble zero = BigDouble._raw(0, 0);
  static const BigDouble one = BigDouble._raw(1, 0);
  static const BigDouble maxValue = BigDouble._raw(1, expLimit);
  static const BigDouble minPositive = BigDouble._raw(1, -expLimit);

  bool get isZero => mantissa == 0;

  bool get isNegative => mantissa < 0;

  /// Lossy by construction.
  double toDouble() {
    if (isZero) return 0;
    return mantissa * _pow10(exponent);
  }

  int get sign => mantissa == 0 ? 0 : (mantissa < 0 ? -1 : 1);

  BigDouble operator +(BigDouble other) {
    if (isZero) return other._styled(style);
    if (other.isZero) return this;

    // When the exponents differ by more than the significant digits, the
    // smaller addend cannot touch a single bit of the result. This is not a
    // speed trick but an identity: in this arithmetic 1e50 + 1e10 EQUALS 1e50.
    final gap = exponent - other.exponent;
    if (gap > maxSignificantDigits) return this;
    if (gap < -maxSignificantDigits) return other._styled(style);

    final bigger = gap >= 0 ? this : other;
    final smaller = gap >= 0 ? other : this;
    final scaled =
        smaller.mantissa / _pow10(bigger.exponent - smaller.exponent);

    return _normalized(bigger.mantissa + scaled, bigger.exponent, style);
  }

  BigDouble operator -(BigDouble other) => this + (-other);

  BigDouble operator *(BigDouble other) {
    if (isZero || other.isZero) return zero._styled(style);
    return _normalized(
      mantissa * other.mantissa,
      _addExponents(exponent, other.exponent),
      style,
    );
  }

  BigDouble operator /(BigDouble other) {
    if (other.isZero) {
      return _domainError(
        'division by zero: $this / $other',
        isZero ? zero : (isNegative ? -maxValue : maxValue),
      );
    }
    if (isZero) return zero._styled(style);
    return _normalized(
      mantissa / other.mantissa,
      _addExponents(exponent, -other.exponent),
      style,
    );
  }

  BigDouble reciprocal() => one / this;

  /// Returns a plain `double`, which is safe: the result never exceeds
  /// [expLimit] = 9e15 in magnitude, and that sits below 2^53 ≈ 9.007e15, the
  /// exact-integer boundary of a `double`. The type limit was chosen partly for
  /// this property.
  double log10() {
    if (sign <= 0) {
      throw ArgumentError.value(
        this,
        'this',
        'logarithm is defined for positive values only',
      );
    }
    return exponent + (math.log(mantissa) / math.ln10);
  }

  double ln() => log10() * math.ln10;

  double log(double base) => log10() / (math.log(base) / math.ln10);

  /// Raises to a power in constant time regardless of the exponent.
  ///
  /// The general path goes through logarithms: `x^p = 10^(log10(x)·p)`. That is
  /// why curves like `1.055^metres` or `1.13^drills` cost the same at metre ten
  /// as at metre ten thousand.
  BigDouble pow(double power) {
    if (power == 0) return one._styled(style);
    if (isZero) return this;
    if (power == 1) return this;

    if (isNegative) {
      // A negative base only makes sense at an integer power; for a fractional
      // one the result is complex, and quietly returning NaN is worse than
      // failing.
      if (power != power.roundToDouble()) {
        throw ArgumentError.value(
          power,
          'power',
          'a fractional power of a negative base is not a real number',
        );
      }
      final magnitude = abs().pow(power);
      return power.toInt().isEven ? magnitude : -magnitude;
    }

    // Integer powers go through multiplication, not logarithms. The log path
    // yields 2^3 = 7.999999999999997, and that error then leaks into prices and
    // thresholds. In this game nearly every power is an integer, so this path
    // is the main one, and for small exponents it is also faster.
    if (power == power.roundToDouble() && power.abs() <= _maxExactIntegerPower) {
      final magnitude = _powBySquaring(power.abs().toInt());
      return (power < 0 ? one / magnitude : magnitude)._styled(style);
    }

    // log10 returns a double, so the product can leave the type's range long
    // before anything becomes an int. Checking before the conversion matters:
    // toInt() on infinity throws, and on a huge value it wraps.
    final logResult = log10() * power;
    if (!logResult.isFinite || logResult.abs() > expLimit) {
      if (logResult.isNegative) return zero._styled(style);
      return maxValue._styled(style);
    }

    final wholePart = logResult.floorToDouble();
    return _normalized(
        _pow10Fractional(logResult - wholePart), wholePart.toInt(), style);
  }

  /// Ceiling for the exact integer-power path.
  ///
  /// Squaring takes about log2(n) multiplications, so even at the limit that is
  /// around thirty operations. Above it the logarithmic path takes over: at
  /// those scales a difference in the last bits stops meaning anything.
  static const double _maxExactIntegerPower = 1e9;

  BigDouble _powBySquaring(int power) {
    var result = one;
    var base = this;
    var remaining = power;

    while (remaining > 0) {
      if (remaining.isOdd) result = result * base;
      remaining >>= 1;
      if (remaining > 0) base = base * base;
    }

    return result;
  }

  BigDouble sqrt() {
    if (isZero) return this;
    if (isNegative) {
      throw ArgumentError.value(
        this,
        'this',
        'the square root of a negative value is not a real number',
      );
    }
    return pow(0.5);
  }

  static double _pow10Fractional(double f) => math.pow(10.0, f).toDouble();

  // Purchase series. Prices in this game grow geometrically (a drill costs
  // 15·1.13^n, a tree node 3·1.4^level). Without these formulas "how many can I
  // buy" becomes a loop running thousands of iterations per tap in a late run.
  // Here it costs constant time.

  static BigDouble sumGeometricSeries(
    BigDouble count,
    BigDouble firstCost,
    BigDouble growth,
    BigDouble owned,
  ) {
    if (count.isZero) return zero;
    final startingPrice = firstCost * growth.pow(owned.toDouble());

    // A growth of exactly one breaks the closed form with a division by zero;
    // there every purchase costs the same.
    if (growth == one) return startingPrice * count;

    return startingPrice * (growth.pow(count.toDouble()) - one) / (growth - one);
  }

  static BigDouble affordGeometricSeries(
    BigDouble resources,
    BigDouble firstCost,
    BigDouble growth,
    BigDouble owned,
  ) {
    final startingPrice = firstCost * growth.pow(owned.toDouble());
    if (resources < startingPrice) return zero;
    if (growth == one) return (resources / startingPrice).floor();

    final ratio = resources / startingPrice * (growth - one) + one;
    return BigDouble.fromNum(ratio.log(growth.toDouble())).floor();
  }

  static BigDouble sumArithmeticSeries(
    BigDouble count,
    BigDouble firstCost,
    BigDouble step,
    BigDouble owned,
  ) {
    if (count.isZero) return zero;
    final startingPrice = firstCost + owned * step;
    final two = BigDouble.fromNum(2);

    return count * (two * startingPrice + (count - one) * step) / two;
  }

  static BigDouble affordArithmeticSeries(
    BigDouble resources,
    BigDouble firstCost,
    BigDouble step,
    BigDouble owned,
  ) {
    final startingPrice = firstCost + owned * step;
    if (resources < startingPrice) return zero;
    if (step.isZero) return (resources / startingPrice).floor();

    // The sum of a linear ladder is quadratic in count, so solve the quadratic
    // and take the positive root.
    final two = BigDouble.fromNum(2);
    final b = startingPrice - step / two;
    final discriminant = b * b + two * step * resources;

    return ((-b + discriminant.sqrt()) / step).floor();
  }

  BigDouble floor() => _rounded((d) => d.floorToDouble());

  BigDouble ceil() => _rounded((d) => d.ceilToDouble());

  BigDouble round() => _rounded((d) => d.roundToDouble());

  BigDouble truncate() => _rounded((d) => d.truncateToDouble());

  /// Past the significant digits a fractional part does not physically exist:
  /// with an exponent at or above [maxSignificantDigits] the mantissa has
  /// nowhere left to hold one, so the value comes back untouched.
  BigDouble _rounded(double Function(double) apply) {
    if (isZero || exponent >= maxSignificantDigits) return this;
    return _normalized(apply(toDouble()), 0, style);
  }

  /// Serializes to `{mantissa}e{exponent}`, the same shape [parse] accepts. One
  /// format for the whole life of a value means a save file stays readable by
  /// eye.
  String toJson() => '${mantissa}e$exponent';

  static BigDouble fromJson(String source) => parse(source);

  /// Accepts `{mantissa}e{exponent}` as well as a plain number.
  static BigDouble parse(String source) {
    final parsed = tryParse(source);
    if (parsed == null) {
      throw FormatException('not a BigDouble', source);
    }
    return parsed;
  }

  static BigDouble? tryParse(String source) {
    final text = source.trim();
    if (text.isEmpty) return null;

    final separator = text.indexOf(RegExp('[eE]'));
    if (separator < 0) {
      final plain = double.tryParse(text);
      return plain == null ? null : _normalized(plain, 0);
    }

    final mantissa = double.tryParse(text.substring(0, separator));
    final exponent = int.tryParse(text.substring(separator + 1));
    if (mantissa == null || exponent == null) return null;

    return _normalized(mantissa, exponent);
  }

  BigDouble abs() =>
      isNegative ? BigDouble._raw(-mantissa, exponent, style) : this;

  BigDouble operator -() =>
      isZero ? this : BigDouble._raw(-mantissa, exponent, style);

  @override
  int compareTo(BigDouble other) {
    // Sign decides everything: any negative is below any positive no matter how
    // large its exponent.
    if (sign != other.sign) return sign < other.sign ? -1 : 1;
    if (isZero) return 0;

    // Within one sign the exponent orders first, the mantissa second. For
    // negatives both comparisons flip.
    final flip = isNegative ? -1 : 1;
    if (exponent != other.exponent) {
      return exponent < other.exponent ? -flip : flip;
    }
    if (mantissa == other.mantissa) return 0;
    return mantissa < other.mantissa ? -1 : 1;
  }

  bool operator <(BigDouble other) => compareTo(other) < 0;

  bool operator <=(BigDouble other) => compareTo(other) <= 0;

  bool operator >(BigDouble other) => compareTo(other) > 0;

  bool operator >=(BigDouble other) => compareTo(other) >= 0;

  BigDouble min(BigDouble other) => this <= other ? this : other;

  BigDouble max(BigDouble other) => this >= other ? this : other;

  BigDouble clamp(BigDouble lowest, BigDouble highest) {
    if (this < lowest) return lowest;
    if (this > highest) return highest;
    return this;
  }

  /// Compares with a RELATIVE tolerance: `|a − b| ≤ tolerance × max(|a|, |b|)`.
  ///
  /// Relative rather than absolute, so the same decision is made the same way
  /// at `1e-100` and at `1e100`.
  bool equalsWithTolerance(BigDouble other,
      [double tolerance = roundTolerance]) {
    if (isZero && other.isZero) return true;
    if (sign != other.sign) return false;

    final difference = (this - other).abs();
    final scale = abs().max(other.abs());
    return difference <= scale * BigDouble.fromNum(tolerance);
  }

  int compareWithTolerance(BigDouble other,
      [double tolerance = roundTolerance]) {
    if (equalsWithTolerance(other, tolerance)) return 0;
    return compareTo(other);
  }

  bool gteWithTolerance(BigDouble other, [double tolerance = roundTolerance]) =>
      compareWithTolerance(other, tolerance) >= 0;

  bool lteWithTolerance(BigDouble other, [double tolerance = roundTolerance]) =>
      compareWithTolerance(other, tolerance) <= 0;

  @override
  bool operator ==(Object other) =>
      other is BigDouble &&
      mantissa == other.mantissa &&
      exponent == other.exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  /// Precedence: the explicit argument, then this number's own style, then
  /// [NumberStyle.global]. One method rather than two, since interpolation goes
  /// down the same path, so no other way to print a number exists.
  @override
  String toString([NumberStyle? style]) =>
      (style ?? this.style ?? NumberStyle.global).format(this);

  static BigDouble _normalized(double mantissa, int exponent,
      [NumberStyle? style]) {
    if (mantissa.isNaN) {
      return _domainError('NaN is not a BigDouble value', zero);
    }
    if (mantissa.isInfinite) {
      return _domainError(
        'infinity is not a BigDouble value',
        mantissa.isNegative ? -maxValue : maxValue,
      );
    }
    if (mantissa == 0) return zero._styled(style);

    final shift = (math.log(mantissa.abs()) / math.ln10).floor();
    var m = shift >= 0 ? mantissa / _pow10(shift) : mantissa * _pow10(-shift);
    var e = exponent + shift;

    // On the boundaries of a power of ten the logarithm is off by a bit, which
    // can push the mantissa outside [1, 10). One correction step is always
    // enough; there is never a second.
    if (m.abs() >= 10) {
      m /= 10;
      e += 1;
    } else if (m.abs() < 1) {
      m *= 10;
      e -= 1;
    }

    // Saturation at the upper limit keeps the sign; falling under the lower one
    // is zero.
    if (e > expLimit) return (m < 0 ? -maxValue : maxValue)._styled(style);
    if (e < -expLimit) return zero._styled(style);

    return BigDouble._raw(m, e, style);
  }

  /// Adds exponents without clamping; [_normalized] applies the type limits.
  ///
  /// An `int` in Dart WRAPS on overflow rather than throwing, so the question is
  /// fair. But both operands already sit within `±expLimit` = ±9e15, so the sum
  /// never exceeds 1.8e16 in magnitude — three orders below the `int64` limit.
  /// Clamping here would be wrong: it would turn an underflow into "smallest
  /// positive" instead of zero.
  static int _addExponents(int a, int b) => a + b;

  static double _pow10(int n) => math.pow(10.0, n).toDouble();
}

extension NumToBigDouble on num {
  BigDouble get big => BigDouble.fromNum(this);
}
