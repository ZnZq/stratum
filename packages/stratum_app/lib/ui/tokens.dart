import 'package:flutter/widgets.dart';

/// The palette, lifted from `prototypes/Stratum.dc.html`.
///
/// The prototype is the project's visual reference, so these are transcribed
/// rather than chosen.
abstract final class Palette {
  static const Color page = Color(0xFF07080B);
  static const Color shell = Color(0xFF0B0C10);
  static const Color bar = Color(0xFF0F1117);
  static const Color card = Color(0xFF171A21);
  static const Color scene = Color(0xFF0E1014);
  static const Color well = Color(0xFF12141A);

  static const Color line = Color(0xFF23262F);
  static const Color lineSoft = Color(0xFF22252E);
  static const Color lineBar = Color(0xFF1B1E26);
  static const Color edge = Color(0xFF3A3F4D);

  static const Color text = Color(0xFFE8E9EE);
  static const Color textDim = Color(0xFFC9CCD6);
  static const Color textMuted = Color(0xFF8B8FA0);
  static const Color textFaint = Color(0xFF565B68);

  static const Color gold = Color(0xFFFFD782);
  static const Color amber = Color(0xFFEF9F27);
  static const Color goldWell = Color(0xFF2B2416);
  static const Color goldInk = Color(0xFF2B1A02);

  static const Color quantonium = Color(0xFFED93B1);
  static const Color sample = Color(0xFFCEC7FF);
  static const Color capsuleTree = Color(0xFF7F77DD);
  static const Color capsuleInk = Color(0xFF1D1745);
  static const Color compute = Color(0xFF9FE1CB);
  static const Color ore = Color(0xFFD3D1C7);
  static const Color boostWell = Color(0xFF123028);

  /// Stratum fills, one pair per stratum, top colour then bottom.
  static const List<List<Color>> strata = [
    [Color(0xFF4A4133), Color(0xFF3A3327)],
    [Color(0xFF45392C), Color(0xFF332B22)],
    [Color(0xFF2F3D3F), Color(0xFF24302F)],
    [Color(0xFF3D3236), Color(0xFF2C2427)],
    [Color(0xFF4A3128), Color(0xFF33221C)],
    [Color(0xFF2C3A4A), Color(0xFF1F2A36)],
    [Color(0xFF3A2F4A), Color(0xFF282036)],
    [Color(0xFF26303E), Color(0xFF181F29)],
  ];

  static const List<Color> thickLayer = [Color(0xFF4A3B1A), Color(0xFF2E2410)];
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
  }) =>
      TextStyle(
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
  }) =>
      TextStyle(
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
  static TextStyle eyebrow({Color color = Palette.textMuted}) => body(
        10,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: 2.5,
      );
}
