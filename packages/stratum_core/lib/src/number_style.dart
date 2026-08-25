import 'big_double.dart';

/// How a large number turns into text.
///
/// A notation is a polymorphic type rather than a set of flags in a config, the
/// way ADNotations models it. The practical reason: the next notation (letters
/// past the table, logarithmic, engineering) becomes a new class instead of a
/// third `switch` scattered through the code.
///
/// The zero / small / large / negative branching is described once, here.
/// Subclasses only implement [formatLarge].
abstract class Notation {
  const Notation();

  String format(BigDouble value, NumberStyle style) {
    if (value.isZero) return '0';
    if (value.isNegative) return '-${format(-value, style)}';

    if (value < style.plainBelow) {
      return _trim(value.toDouble().toStringAsFixed(style.placesPlain), style);
    }

    return formatLarge(value, style);
  }

  /// Always receives a positive value no smaller than [NumberStyle.plainBelow].
  String formatLarge(BigDouble value, NumberStyle style);

  static String _trim(String text, NumberStyle style) {
    if (!style.trimTrailingZeros || !text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String formatMantissa(double mantissa, int places, NumberStyle style) =>
      _trim(mantissa.toStringAsFixed(places), style);
}

/// The genre-standard suffix form: `1.5k`, `12.3m`, `4.2d`.
///
/// Past the end of the table it switches to [ScientificNotation]. The genre
/// calls that behaviour Mixed Scientific, and the boundary matches the one
/// ADNotations switches at.
class SuffixNotation extends Notation {
  const SuffixNotation();

  /// Lives here, so localisation is a different notation instance rather than a
  /// code change.
  static const List<String> suffixes = [
    'k', 'm', 'b', 't', 'qa', 'qu', 'sx', 'sp', 'o', 'n', 'd',
  ];

  /// The first exponent with no suffix left.
  static const int ceilingExponent = 36;

  static const ScientificNotation _fallback = ScientificNotation();

  @override
  String formatLarge(BigDouble value, NumberStyle style) {
    var exponent = value.exponent;
    var mantissa = value.mantissa * _powersOfTen[exponent % 3];

    // Rounding can push the number across a tier boundary on its own: 999.999
    // at two places becomes 1000.00, and printing that as "1000sx" instead of
    // "1sp" would be wrong. So the tier is picked after rounding, not before.
    mantissa = double.parse(mantissa.toStringAsFixed(style.places));
    if (mantissa.abs() >= 1000) {
      mantissa /= 1000;
      exponent += 3;
    }

    if (exponent >= ceilingExponent) {
      return _fallback.formatLarge(value, style);
    }

    return Notation.formatMantissa(mantissa, style.places, style) +
        suffixes[exponent ~/ 3 - 1];
  }

  static const List<double> _powersOfTen = [1, 10, 100];
}

class ScientificNotation extends Notation {
  const ScientificNotation();

  @override
  String formatLarge(BigDouble value, NumberStyle style) {
    var mantissa = double.parse(value.mantissa.toStringAsFixed(style.places));
    var exponent = value.exponent;

    // Same trap as the suffixes: 9.999 at two places becomes 10.00, and
    // "10.00e5" is not scientific notation.
    if (mantissa.abs() >= 10) {
      mantissa /= 10;
      exponent += 1;
    }

    return '${Notation.formatMantissa(mantissa, style.places, style)}'
        'e${exponent.toStringAsFixed(style.placesExponent)}';
  }
}

/// An immutable, const-constructible description of number output, so presets
/// are compile-time constants and attaching one to a number costs nothing.
class NumberStyle {
  const NumberStyle({
    this.notation = const SuffixNotation(),
    this.places = 2,
    this.placesPlain = 1,
    this.placesExponent = 0,
    this.plainBelow = _thousand,
    this.trimTrailingZeros = true,
  });

  final Notation notation;

  /// Fraction digits for numbers rendered through the notation.
  final int places;

  /// Fraction digits for numbers printed as plain digits.
  final int placesPlain;

  final int placesExponent;

  /// Below this the number is printed as plain digits, without a notation.
  final BigDouble plainBelow;

  final bool trimTrailingZeros;

  static const BigDouble _thousand = BigDouble.fromMantissaExponent(1, 3);
  static const BigDouble _quadrillion = BigDouble.fromMantissaExponent(1, 15);

  static const NumberStyle compact = NumberStyle();

  static const NumberStyle scientific = NumberStyle(
    notation: ScientificNotation(),
  );

  /// Whole quantities without suffixes: depth in metres should read as metres.
  ///
  /// The plain threshold is raised to 1e15 because past that a suffix is easier
  /// to read than a sixteen-digit number.
  static const NumberStyle integer = NumberStyle(
    placesPlain: 0,
    plainBelow: _quadrillion,
  );

  /// The game-wide default. Mutable at runtime because it is a player setting.
  static NumberStyle global = compact;

  String format(BigDouble value) => notation.format(value, this);
}
