import 'package:flutter/widgets.dart';

/// The palette.
///
/// Based on `prototypes/Stratum.dc.html`, then lifted well above it: the
/// prototype reads as an unlit cave, and this is meant to read as a lit
/// instrument -- cool slate rather than near-black, with the rock light
/// enough that its grain is visible instead of implied.
abstract final class Palette {
  static const Color page = Color(0xFF141B26);
  static const Color shell = Color(0xFF1A222F);
  static const Color bar = Color(0xFF1E2834);
  static const Color card = Color(0xFF283442);
  static const Color scene = Color(0xFF1D2734);
  static const Color well = Color(0xFF232E3C);

  static const Color line = Color(0xFF3C4A5C);
  static const Color lineSoft = Color(0xFF38465C);
  static const Color lineBar = Color(0xFF2E3A48);
  static const Color edge = Color(0xFF5A6980);

  static const Color text = Color(0xFFF1F3F8);
  static const Color textDim = Color(0xFFD6DDE9);
  static const Color textMuted = Color(0xFFA0ADC1);
  static const Color textFaint = Color(0xFF7C8A9C);

  static const Color gold = Color(0xFFFFD782);
  static const Color amber = Color(0xFFEF9F27);
  static const Color goldWell = Color(0xFF3B3120);
  static const Color goldInk = Color(0xFF2B1A02);

  static const Color quantonium = Color(0xFFED93B1);
  static const Color sample = Color(0xFFCEC7FF);
  static const Color capsuleTree = Color(0xFF7F77DD);
  static const Color capsuleInk = Color(0xFF2A2258);
  static const Color compute = Color(0xFF9FE1CB);
  static const Color ore = Color(0xFFD3D1C7);

  /// Instrument accent: rulers, tick marks, technical captions.
  static const Color tech = Color(0xFF7FD9C4);
  static const Color steel = Color(0xFF85B7EB);
  static const Color boostWell = Color(0xFF1B4036);

  /// Stratum fills, one pair per stratum, top colour then bottom.
  ///
  /// These are only the ground tone: the grain, clasts and bedding planes are
  /// painted over them, so each pair is kept light enough for that detail to
  /// read.
  static const List<List<Color>> strata = [
    [Color(0xFF9A8B70), Color(0xFF77694F)],
    [Color(0xFF93805F), Color(0xFF6D5D42)],
    [Color(0xFF6B8589), Color(0xFF4E6669)],
    [Color(0xFF82707A), Color(0xFF60515C)],
    [Color(0xFF9A6E56), Color(0xFF6F4E3C)],
    [Color(0xFF627D98), Color(0xFF465D76)],
    [Color(0xFF7A669B), Color(0xFF574975)],
    [Color(0xFF5C7089), Color(0xFF42556B)],
  ];

  static const List<Color> thickLayer = [Color(0xFF9C7E3C), Color(0xFF6B5522)];
}

abstract final class Strata {
  static const List<String> names = [
    'Реголіт',
    'Осадові',
    'Кристалічні',
    'Базальт',
    'Мантійні',
    'Плазмові',
    'Екзо-шар',
    'Квантові',
  ];

  static String nameFor(int layer) {
    final index = layer ~/ 50;
    return names[index < names.length ? index : names.length - 1];
  }

  static List<Color> fillFor(int layer) {
    final index = layer ~/ 50;
    return Palette.strata[index < Palette.strata.length
        ? index
        : Palette.strata.length - 1];
  }
}

/// Heights of the chrome that floats over a full-bleed screen.
///
/// Shared so a screen can keep its content clear of the strip and the tabs
/// without guessing at their size.
abstract final class AppMetrics {
  static const double resourceBar = 48;
  static const double navBar = 52;
}

/// Type roles.
///
/// [display] is Chakra Petch, which the prototype uses for every number and
/// readout — it carries the instrument-panel tone. [body] is Manrope for prose
/// and labels.
///
/// Manrope ships as a variable font, so the weight travels as a `wght` axis
/// value. Setting `fontWeight` as well keeps the fallback path honest if the
/// axis is ever unavailable.
abstract final class AppText {
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = Palette.text,
    double? letterSpacing,
    double height = 1.15,
    bool shadows = false,
  }) => TextStyle(
    fontFamily: 'ChakraPetch',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows ? _lift : null,
  );

  /// Keeps a readout legible over the strata, which are busy and mid-toned.
  static const List<Shadow> _lift = [
    Shadow(color: Color(0xD9000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = Palette.text,
    double? letterSpacing,
    double height = 1.3,
    bool shadows = false,
  }) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    shadows: shadows ? _lift : null,
  );

  /// The small uppercase caption the prototype puts above readouts.
  static TextStyle eyebrow({Color color = Palette.textMuted}) =>
      body(10, weight: FontWeight.w600, color: color, letterSpacing: 2.5);
}
