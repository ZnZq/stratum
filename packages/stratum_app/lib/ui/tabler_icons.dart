import 'package:flutter/widgets.dart';

/// The Tabler glyphs the prototype uses, by codepoint.
///
/// Spelled out as const literals rather than pulled from a package so the build
/// can subset the font: a release build ships these glyphs instead of the five
/// thousand sitting in the file.
abstract final class Ti {
  static const IconData stack2 = IconData(0xeef7, fontFamily: 'TablerIcons');
  static const IconData atom2 = IconData(0xebdf, fontFamily: 'TablerIcons');
  static const IconData diamond = IconData(0xeb65, fontFamily: 'TablerIcons');
  static const IconData cpu = IconData(0xef8e, fontFamily: 'TablerIcons');
  static const IconData capsule = IconData(0xfae3, fontFamily: 'TablerIcons');
  static const IconData settings2 = IconData(0xf5ac, fontFamily: 'TablerIcons');
  static const IconData flame = IconData(0xec2c, fontFamily: 'TablerIcons');
  static const IconData refresh = IconData(0xeb13, fontFamily: 'TablerIcons');
  static const IconData arrowBarDown =
      IconData(0xea0d, fontFamily: 'TablerIcons');
  static const IconData binaryTree =
      IconData(0xf5d4, fontFamily: 'TablerIcons');
  static const IconData planet = IconData(0xec08, fontFamily: 'TablerIcons');
  static const IconData tools = IconData(0xebca, fontFamily: 'TablerIcons');
  static const IconData userHexagon =
      IconData(0xfc4e, fontFamily: 'TablerIcons');
}
