import 'package:flutter/widgets.dart';
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
  ResourceId.ore: (
    label: 'Руда',
    note: 'кожен цикл',
    icon: Ti.stack2,
    colour: Palette.ore,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.crystals: (
    label: 'Кристали',
    note: 'шанс за цикл, більші з глибиною',
    icon: Ti.diamond,
    colour: Palette.crystal,
    shelf: ResourceShelf.extracted,
  ),
  ResourceId.quantonium: (
    label: 'Квантоніум',
    note: 'шанс за цикл · поріг перезапуску',
    icon: Ti.atom2,
    colour: Palette.quantonium,
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

/// The order the warehouse walks, shelf by shelf.
Iterable<ResourceId> resourcesOn(ResourceShelf shelf) => resourceStyles.entries
    .where((entry) => entry.value.shelf == shelf)
    .map((entry) => entry.key);
