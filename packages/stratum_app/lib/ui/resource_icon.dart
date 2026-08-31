import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stratum_core/stratum_core.dart';

import 'resource_style.dart';

/// A resource's face, wherever one is shown.
///
/// One widget instead of `Icon(style.icon)` scattered around, so swapping a
/// glyph for bespoke art -- or adding art for a new resource -- happens in
/// [resourceSvgs] and nowhere else.
class ResourceIcon extends StatelessWidget {
  const ResourceIcon(this.id, {required this.size, this.colour, super.key});

  final ResourceId id;
  final double size;

  /// Overrides the resource's own colour, e.g. to dim a locked entry.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    final svg = resourceSvgs[id];
    if (svg == null) {
      return Icon(style.icon, size: size, color: colour ?? style.colour);
    }
    // The bespoke faces are little specimens with palettes of their own, so
    // they are never flattened by a tint. A colour override means the caller
    // wanted the entry subdued -- honoured as translucency instead.
    final image = SvgPicture.asset(svg, width: size, height: size);
    if (colour == null) return image;
    return Opacity(opacity: 0.55, child: image);
  }
}
