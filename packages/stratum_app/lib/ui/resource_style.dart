import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stratum_core/stratum_core.dart';

import 'tabler_icons.dart';
import 'tokens.dart';

/// Which shelf of the warehouse a resource sits on.
enum ResourceShelf {
  /// Cut out of the planet.
  extracted('видобуток'),

  /// Spent on progress the player keeps across a reset.
  currency('валюти'),

  /// Neither mined nor spent on the rig: what the simulation itself yields.
  research('дослідження');

  const ResourceShelf(this.label);

  final String label;
}

/// How one resource is presented.
///
/// Kept out of the core: the ledger knows amounts, and nothing there should
/// have an opinion about icons, colours or Ukrainian names.
typedef ResourceStyle = ({
  String label,
  String note,
  IconData icon,
  Color colour,
  ResourceShelf shelf,
});

const Map<ResourceId, ResourceStyle> resourceStyles = {
  ResourceId.regolith: (
    label: 'Реголіт',
    note: 'перемелена порода · кожен удар',
    icon: Ti.grain,
    colour: Palette.ore,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.cuprite: (
    label: 'Куприт',
    note: 'мідна руда · шанс з удару',
    icon: Ti.circles,
    colour: Palette.cuprite,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.ferrite: (
    label: 'Ферит',
    note: 'залізна руда · з 50 м',
    icon: Ti.magnet,
    colour: Palette.ferrite,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.silicite: (
    label: 'Силіцит',
    note: 'кремнієвий мінерал · зі 100 м',
    icon: Ti.prism,
    colour: Palette.silicite,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.crystals: (
    label: 'Кристали',
    note: 'шанс з удару, більші з глибиною',
    icon: Ti.diamond,
    colour: Palette.crystal,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.quantonium: (
    label: 'Квантоніум',
    note: 'рідкісний шанс з удару · застосування згодом',
    icon: Ti.atom2,
    colour: Palette.quantonium,
    shelf: ResourceShelf.currency,
  ),
  ResourceId.credits: (
    label: 'Кредити',
    note: 'з продажу видобутого · покращення рига',
    icon: Ti.stack2,
    colour: Palette.gold,
    shelf: ResourceShelf.currency,
  ),
  ResourceId.capsules: (
    label: 'Капсули',
    note: 'за перезапуск · дерево симуляції',
    icon: Ti.capsule,
    colour: Palette.gold,
    shelf: ResourceShelf.currency,
  ),
  ResourceId.cores: (
    label: 'Ядра',
    note: 'за колапс · мета-дерево',
    icon: Ti.sphere,
    colour: Palette.steel,
    shelf: ResourceShelf.currency,
  ),
  ResourceId.samples: (
    label: 'Зразки',
    note: 'перший товстий шар у симуляції',
    icon: Ti.flask2,
    colour: Palette.sample,
    shelf: ResourceShelf.research,
  ),
  ResourceId.compute: (
    label: 'Фонові обчислення',
    note: 'накопичуються тільки офлайн',
    icon: Ti.cpu,
    colour: Palette.compute,
    shelf: ResourceShelf.research,
  ),
};

/// The bespoke faces. Resources missing here fall back to their Tabler
/// glyph, so a new resource works before anyone has drawn it.
const Map<ResourceId, String> resourceSvgs = {
  ResourceId.regolith: 'assets/icons/regolith.svg',
  ResourceId.cuprite: 'assets/icons/cuprite.svg',
  ResourceId.ferrite: 'assets/icons/ferrite.svg',
  ResourceId.silicite: 'assets/icons/silicite.svg',
  ResourceId.crystals: 'assets/icons/crystals.svg',
  ResourceId.quantonium: 'assets/icons/quantonium.svg',
  ResourceId.credits: 'assets/icons/credits.svg',
  ResourceId.samples: 'assets/icons/samples.svg',
  ResourceId.capsules: 'assets/icons/capsules.svg',
  ResourceId.cores: 'assets/icons/cores.svg',
  ResourceId.compute: 'assets/icons/compute.svg',
};

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

/// The order the warehouse walks, shelf by shelf.
Iterable<ResourceId> resourcesOn(ResourceShelf shelf) => resourceStyles.entries
    .where((entry) => entry.value.shelf == shelf)
    .map((entry) => entry.key);
