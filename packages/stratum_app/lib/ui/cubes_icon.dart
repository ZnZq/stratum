import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'resource_style.dart';

/// The cubes' face, at the size asked for. A specimen like the resources,
/// so it is drawn as it was painted -- no tint.
class CubesIcon extends StatelessWidget {
  const CubesIcon({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset(cubesSvg, width: size, height: size);
}
