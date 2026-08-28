import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';

/// The game's own glyphs, for navigation and for ideas the game has words for.
///
/// A second icon family beside the resource specimens, and deliberately not
/// the same kind of drawing. A resource is a MATERIAL -- it is drawn in its
/// own colours and never tinted. A glyph is a SIGN: one flat shape that takes
/// whatever colour the state it stands in calls for, which is the only way an
/// icon can go from faint to gold when a tab lights up.
///
/// Drawn rather than borrowed so the game has one voice: every one is on the
/// same 24-unit grid, the same stroke weight, the same round joins, and reads
/// at the 13 px a nav chip gives it.
abstract final class Ic {
  static const String _at = 'assets/icons/';

  // Sections.
  static const String extraction = '${_at}nav_extraction.svg';
  static const String production = '${_at}nav_production.svg';
  static const String research = '${_at}nav_research.svg';
  static const String console = '${_at}nav_console.svg';

  // Screens.
  static const String mine = '${_at}nav_mine.svg';
  static const String arm = '${_at}nav_arm.svg';
  static const String drills = '${_at}nav_drills.svg';
  static const String planets = '${_at}nav_planets.svg';
  static const String craft = '${_at}nav_craft.svg';
  static const String building = '${_at}nav_building.svg';
  static const String lab = '${_at}nav_lab.svg';
  static const String tree = '${_at}nav_tree.svg';
  static const String avatar = '${_at}nav_avatar.svg';
  static const String samples = '${_at}nav_samples.svg';
  static const String settings = '${_at}nav_settings.svg';
  static const String daily = '${_at}nav_daily.svg';
  static const String achievements = '${_at}nav_achievements.svg';
  static const String stats = '${_at}nav_stats.svg';
  static const String account = '${_at}nav_account.svg';
  static const String saves = '${_at}nav_saves.svg';

  // Ideas the game keeps saying out loud.
  static const String depth = '${_at}sym_depth.svg';
  static const String rawData = '${_at}sym_raw_data.svg';
  static const String dataWallet = '${_at}sym_data_wallet.svg';
  static const String collapse = '${_at}sym_collapse.svg';
  static const String energy = '${_at}sym_energy.svg';
  static const String crit = '${_at}sym_crit.svg';
  static const String pause = '${_at}sym_pause.svg';
  static const String background = '${_at}sym_background.svg';
}

/// One glyph, in whatever colour its place calls for.
class GameIcon extends StatelessWidget {
  const GameIcon(
    this.glyph, {
    required this.size,
    this.colour = Palette.textFaint,
    super.key,
  });

  final String glyph;
  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      glyph,
      width: size,
      height: size,
      // The art is drawn in one flat white, so the filter is a straight
      // recolour rather than a wash over something that already has colours
      // of its own -- which is exactly why resources do NOT go through here.
      colorFilter: ColorFilter.mode(colour, BlendMode.srcIn),
    );
  }
}
