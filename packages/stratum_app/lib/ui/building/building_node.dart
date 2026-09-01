import 'dart:ui';

import '../tokens.dart';

/// One building on the construction graph.
///
/// A table row, not a widget: PLACING a node is editing [pos] here, and a
/// new building is a new row plus its edges via [requires]. The mechanics
/// (component costs, levels, effects) come later -- today the graph is a
/// DRAFT of the run-scoped tree (resets on every Restart; see the journal).
/// The three breeds of the run tree (owner's spec) plus the root.
enum NodeBreed { root, oneShot, fewStrong, manySmall }

class BuildingNode {
  const BuildingNode({
    required this.id,
    required this.label,
    required this.colour,
    required this.pos,
    this.requires = const [],
    this.note = '',
    this.unlock,
    this.breed = '',
    this.kind = NodeBreed.oneShot,
    this.diamond = false,
    this.locked = false,
    this.simGated = false,
  });

  final String id;
  final String label;
  final Color colour;

  /// The node's centre on the graph canvas, in canvas units.
  final Offset pos;

  /// Parent node ids; every entry draws an edge. Two parents make the node
  /// a merge -- the simulation tree's diamond language.
  final List<String> requires;

  /// The one-line effect.
  final String note;

  /// What it OPENS, if anything: a mechanic, recipes, a resource.
  final String? unlock;

  /// The node's breed, quoted in the passport: one-shot / few strong
  /// levels / many small levels.
  final String breed;

  /// The breed as a switch, for the disc's core glyph.
  final NodeBreed kind;

  /// Drawn with the merge glyph.
  final bool diamond;

  /// Not reachable yet: dimmed, its condition in the panel.
  final bool locked;

  /// Locked until a SIMULATION-TREE node is bought -- the meta layer
  /// above this run-scoped tree.
  final bool simGated;
}

/// The web, DRAFT: the foundation in the centre, five sectors radiating
/// outward on ring orbits (r 190 / 320 / 450). Chains run outward along
/// their bearing. Every number and cost is a placeholder by rule zero.
const List<BuildingNode> buildingNodes = [
  BuildingNode(
    id: 'foundation',
    label: 'ФУНДАМЕНТ',
    colour: Palette.textDim,
    pos: Offset(560, 545),
    note: 'гирло шахти · серце комплексу',
    kind: NodeBreed.root,
  ),

  // ================= ВИДОБУТОК (захід) =================
  // -- шахта
  BuildingNode(
    id: 'shoring',
    label: 'КРІПЛЕННЯ СТОВБУРА',
    colour: Palette.tech,
    pos: Offset(395, 640),
    requires: ['foundation'],
    note: '+% реголіту з удару',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'blasting',
    label: 'ВИБУХОВІ РОБОТИ',
    colour: Palette.tech,
    pos: Offset(283, 705),
    requires: ['shoring'],
    note: 'множник шкоди по шару',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'sensorMast',
    label: 'СЕНСОРНА ЩОГЛА',
    colour: Palette.tech,
    pos: Offset(170, 770),
    requires: ['blasting'],
    note: 'рівень = +2 шари прогнозу',
    unlock: 'розвідка шарів',
    breed: 'one-shot + рівні',
    kind: NodeBreed.oneShot,
    locked: true,
  ),
  // -- маніпулятор
  BuildingNode(
    id: 'hydraulics',
    label: 'ГІДРАВЛІКА',
    colour: Palette.tech,
    pos: Offset(372, 571),
    requires: ['foundation'],
    note: '+% сили удару руки',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'capacitors',
    label: 'КОНДЕНСАТОРИ',
    colour: Palette.tech,
    pos: Offset(243, 589),
    requires: ['hydraulics'],
    note: '×ємність енергії',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'recuperator',
    label: 'РЕКУПЕРАТОР',
    colour: Palette.tech,
    pos: Offset(115, 608),
    requires: ['capacitors'],
    note: 'злам шару повертає енергію',
    unlock: 'нова мікромеханіка',
    breed: 'one-shot',
    kind: NodeBreed.oneShot,
    locked: true,
  ),
  // -- бур
  BuildingNode(
    id: 'rigTower',
    label: 'БУРОВА ВЕЖА',
    colour: Palette.tech,
    pos: Offset(376, 496),
    requires: ['foundation'],
    note: 'рівень = слот типізованого бура',
    unlock: 'типізовані бури',
    breed: 'one-shot + рівні · слоти 3+ за сим-деревом',
    kind: NodeBreed.oneShot,
  ),
  BuildingNode(
    id: 'lubrication',
    label: 'ЗМАЩУВАЛЬНИЙ КОНТУР',
    colour: Palette.tech,
    pos: Offset(251, 462),
    requires: ['rigTower'],
    note: '+% темпу циклів бурів',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'wideBit',
    label: 'РОЗШИРЕНА КОРОНКА',
    colour: Palette.tech,
    pos: Offset(125, 429),
    requires: ['lubrication'],
    note: '+радіус охвату бурів',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  // -- ресурси
  BuildingNode(
    id: 'separator',
    label: 'СЕПАРАТОР',
    colour: Palette.ore,
    pos: Offset(408, 431),
    requires: ['foundation'],
    note: '+% шансу руд',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'resonator',
    label: 'КРИСТ. РЕЗОНАТОР',
    colour: Palette.crystal,
    pos: Offset(304, 352),
    requires: ['separator'],
    note: '+шанс і обсяг кристалів',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'deepAnalyzer',
    label: 'ГЛИБИННИЙ АНАЛІЗАТОР',
    colour: Palette.ore,
    pos: Offset(200, 274),
    requires: ['resonator'],
    note: 'відкриває новий видобувний ресурс',
    unlock: 'відкладені руди',
    breed: 'one-shot',
    kind: NodeBreed.oneShot,
    locked: true,
    simGated: true,
  ),

  // ================= ДАТАЦЕНТР (північ) =================
  BuildingNode(
    id: 'rack',
    label: 'СТІЙКА ДЦ',
    colour: Palette.gold,
    pos: Offset(560, 355),
    requires: ['foundation'],
    note: '+1 до стіни колапсів за рівень',
    breed: 'мало рівнів · кап за сим-деревом',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'dataBuffer',
    label: 'БУФЕР ДАНИХ',
    colour: Palette.gold,
    pos: Offset(417, 340),
    requires: ['rack'],
    note: '+% сирих даних з удару',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'cooling',
    label: 'ОХОЛОДЖЕННЯ',
    colour: Color(0xFF9C8FE8),
    pos: Offset(451, 244),
    requires: ['rack'],
    note: '+кап нагріву (діб дрейфу)',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'compiler',
    label: 'КОМПІЛЯТОР',
    colour: Palette.gold,
    pos: Offset(560, 225),
    requires: ['rack'],
    note: '+compileRate: більше кубів — ближчий колапс',
    breed: 'мало рівнів · один важіль, два ефекти',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'analytics',
    label: 'СЕРВЕР АНАЛІТИКИ',
    colour: Color(0xFF9C8FE8),
    pos: Offset(654, 105),
    requires: ['cooling', 'compiler'],
    note: 'злиття гілки',
    unlock: 'екран Аналітики',
    breed: 'one-shot · ромб',
    kind: NodeBreed.oneShot,
    diamond: true,
    locked: true,
  ),

  // ================= КОМПЛЕКС (північний схід) =================
  BuildingNode(
    id: 'powerGrid',
    label: 'ЕНЕРГОМЕРЕЖА',
    colour: Color(0xFF9C8FE8),
    pos: Offset(716, 436),
    requires: ['foundation'],
    note: '+% темпу регену енергії',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'replication',
    label: 'ЛАБ. РЕПЛІКАЦІЇ',
    colour: Palette.steel,
    pos: Offset(766, 300),
    requires: ['powerGrid'],
    note: 'рівень = темп реплікації',
    unlock: 'механіка реплікації',
    breed: 'one-shot + рівні',
    kind: NodeBreed.oneShot,
    locked: true,
  ),
  BuildingNode(
    id: 'dock',
    label: 'САТЕЛІТНИЙ ДОК',
    colour: Palette.textFaint,
    pos: Offset(902, 237),
    requires: ['replication'],
    note: 'одноразова · далеко',
    unlock: 'сателіти',
    breed: 'one-shot',
    kind: NodeBreed.oneShot,
    locked: true,
    simGated: true,
  ),

  // ================= КРАФТ (схід) =================
  BuildingNode(
    id: 'beltDrives',
    label: 'КОНВЕЄРНІ ПРИВОДИ',
    colour: Palette.steel,
    pos: Offset(747, 578),
    requires: ['foundation'],
    note: '+% швидкості всіх ліній',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'overdrive',
    label: 'ФОРСАЖ ПЕЧЕЙ',
    colour: Palette.steel,
    pos: Offset(895, 604),
    requires: ['beltDrives'],
    note: '×темп крафту',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'flywheels',
    label: 'МАХОВИКИ',
    colour: Palette.steel,
    pos: Offset(1020, 643),
    requires: ['overdrive'],
    note: '+кап стеків розгону',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
    locked: true,
  ),
  BuildingNode(
    id: 'furnace',
    label: 'ДОМЕННА ПІЧ',
    colour: Palette.steel,
    pos: Offset(721, 646),
    requires: ['foundation'],
    note: 'нові рецепти плавки',
    unlock: 'нові рецепти',
    breed: 'one-shot',
    kind: NodeBreed.oneShot,
  ),
  BuildingNode(
    id: 'techBureau',
    label: 'ТЕХНОЛОГІЧНЕ БЮРО',
    colour: Palette.steel,
    pos: Offset(848, 725),
    requires: ['furnace'],
    note: 'рецепти вищого тиру технологій',
    unlock: 'нові рецепти',
    breed: 'one-shot',
    kind: NodeBreed.oneShot,
    locked: true,
    simGated: true,
  ),
  BuildingNode(
    id: 'assemblyShop',
    label: 'СКЛАДАЛЬНИЙ ЦЕХ',
    colour: Palette.steel,
    pos: Offset(746, 506),
    requires: ['foundation'],
    note: '+1 крафт-лінія за рівень',
    breed: 'мало рівнів · кап за сим-деревом',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'presses',
    label: 'ПРЕСИ',
    colour: Palette.steel,
    pos: Offset(893, 474),
    requires: ['assemblyShop'],
    note: '+2 до стелі компресії ліній',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'qualityControl',
    label: 'КОНТРОЛЬ ЯКОСТІ',
    colour: Palette.steel,
    pos: Offset(823, 449),
    requires: ['presses'],
    note: '+% шансу дубля',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
    locked: true,
  ),

  // ================= ТОРГІВЛЯ (південь) =================
  BuildingNode(
    id: 'brokerNet',
    label: 'БРОКЕРСЬКА МЕРЕЖА',
    colour: Palette.credit,
    pos: Offset(666, 772),
    requires: ['foundation'],
    note: '+% до прейскуранта',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
  ),
  BuildingNode(
    id: 'tradeTerminal',
    label: 'ТЕРМІНАЛ ЗАПИТІВ',
    colour: Palette.credit,
    pos: Offset(543, 734),
    requires: ['foundation'],
    note: '+1 слот запитів за рівень',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
  ),
  BuildingNode(
    id: 'logisticsHub',
    label: 'ЛОГІСТИЧНИЙ ХАБ',
    colour: Palette.credit,
    pos: Offset(532, 864),
    requires: ['tradeTerminal'],
    note: '−інтервал появи запитів',
    breed: 'багато рівнів · дрібний множник',
    kind: NodeBreed.manySmall,
    locked: true,
  ),
  BuildingNode(
    id: 'premiumDeals',
    label: 'ПРЕМІУМ-КОНТРАКТИ',
    colour: Palette.credit,
    pos: Offset(521, 993),
    requires: ['logisticsHub'],
    note: '+діапазон премії запитів',
    breed: 'мало рівнів · відчутний множник',
    kind: NodeBreed.fewStrong,
    locked: true,
    simGated: true,
  ),
  BuildingNode(
    id: 'autoSell',
    label: 'АВТОПРОДАЖ',
    colour: Palette.credit,
    pos: Offset(428, 757),
    requires: ['foundation'],
    note: 'авто-продаж за налаштуваннями Продажу',
    unlock: 'автоматизація торгівлі',
    breed: 'one-shot · кандидат на «стартує активним»',
    kind: NodeBreed.oneShot,
    locked: true,
  ),
];

/// A sector of the web: one zone of responsibility, its caption drawn
/// faint at the field's rim on that bearing.
class BuildingSector {
  const BuildingSector(this.label, this.colour, this.at, this.bearing);

  final String label;
  final Color colour;
  final Offset at;

  /// The sector's direction from the centre, in screen radians (y down):
  /// 0 = east, pi/2 = south, pi = west, -pi/2 = north. The field paints
  /// each sector's wedge between the midpoints to its neighbours, so a
  /// new sector only needs its own bearing.
  final double bearing;
}

const List<BuildingSector> buildingSectors = [
  BuildingSector('ВИДОБУТОК', Palette.tech, Offset(150, 860), 3.1416),
  BuildingSector('ДАТАЦЕНТР', Palette.gold, Offset(470, 62), -1.5708),
  BuildingSector('КОМПЛЕКС', Color(0xFF9C8FE8), Offset(940, 130), -0.7854),
  BuildingSector('КРАФТ', Palette.steel, Offset(1045, 380), 0),
  BuildingSector('ТОРГІВЛЯ', Palette.credit, Offset(700, 1035), 1.5708),
];

/// The canvas the web is laid out on; the foundation sits at its centre.
const Size buildingCanvasSize = Size(1120, 1090);
const Offset buildingCanvasCentre = Offset(560, 545);

BuildingNode buildingNodeOf(String id) =>
    buildingNodes.firstWhere((node) => node.id == id);
