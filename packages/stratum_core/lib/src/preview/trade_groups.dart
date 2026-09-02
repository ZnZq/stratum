import '../stockpile.dart';

/// The shelves the trade hall and the tier tables share: which resources
/// belong together, in the order the hall lists them. The key names the
/// tier every tier-priced mechanic (the replicator's tolls, yields and
/// steps) reads from.
const List<({String key, List<ResourceId> ids})> tradeGroupTable = [
  (
    key: 'resources',
    ids: [ResourceId.regolith, ResourceId.cuprite, ResourceId.ferrite],
  ),
  (
    key: 'materials',
    ids: [ResourceId.cuprum, ResourceId.ferrum, ResourceId.silicon],
  ),
  (
    key: 'building',
    ids: [ResourceId.wire, ResourceId.frame, ResourceId.reinforcedGlass],
  ),
  (
    key: 'tech',
    ids: [
      ResourceId.chip,
      ResourceId.processor,
      ResourceId.sensor,
      ResourceId.module,
    ],
  ),
];

/// The tier key [id] sells under, or null for what no shelf lists.
String? tierKeyOf(ResourceId id) {
  for (final group in tradeGroupTable) {
    if (group.ids.contains(id)) return group.key;
  }
  return null;
}
