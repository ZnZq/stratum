import 'package:stratum_core/stratum_core.dart';

/// How one part of the arm is presented.
///
/// Kept out of the core for the same reason resource styles are: the
/// simulation knows levels and rates, and has no opinion about Ukrainian
/// names.
typedef ArmPartStyle = ({String label, String note});

const Map<ArmPart, ArmPartStyle> armPartStyles = {
  ArmPart.bit: (label: 'Біт', note: 'те, чим бʼє'),
  ArmPart.drive: (label: 'Привід', note: 'те, що вганяє біт у породу'),
  ArmPart.supply: (label: 'Живлення', note: 'накопичувач у плечі'),
};

/// One buff a part carries: what it is called, what a level adds, and what
/// the levels bought so far add up to.
class ArmBuff {
  const ArmBuff({
    required this.label,
    required this.step,
    required this.total,
    this.fromGeneration = 0,
  });

  final String label;

  /// What one level is worth, in words the row can print as-is.
  final String step;

  /// The accumulated effect, read off the live simulation.
  final String Function(PrototypeSimulation sim) total;

  /// The generation that opens this buff. Nothing below it is drawn at all:
  /// a buff a part has not grown yet simply is not in the list.
  final int fromGeneration;
}

/// Every buff, by part, in the order the card lists them.
///
/// A table rather than a switch: a buff added later -- or a generation given
/// one of its own -- is a row here, and no other file has to hear about it.
///
/// The steps are printed FROM the core's constants, never typed beside
/// them: a tuned number would otherwise leave the card promising one step
/// and the total paying another.
final Map<ArmPart, List<ArmBuff>> armBuffs = {
  ArmPart.bit: [
    ArmBuff(
      label: 'базова потужність',
      step: '+${_flat(PrototypeSimulation.basePowerPerLevel)} / рів.',
      total: _bitPower,
    ),
    ArmBuff(
      label: 'мін. реголіт',
      step: '×${PrototypeSimulation.minRegolithGrowth} / рів.',
      total: _bitMinRegolith,
    ),
  ],
  ArmPart.drive: [
    ArmBuff(
      label: 'пробивання',
      step: '+${_percent(PrototypeSimulation.piercePerLevel, 3)} / рів.',
      total: _drivePierce,
    ),
    ArmBuff(
      label: 'макс. реголіт',
      step: '×${PrototypeSimulation.maxRegolithGrowth} / рів.',
      total: _driveMaxRegolith,
    ),
  ],
  ArmPart.supply: [
    ArmBuff(
      label: 'ємність енергії',
      step: '+${PrototypeSimulation.energyPerCapLevel} / рів.',
      total: _supplyCap,
    ),
    ArmBuff(
      label: 'швидкість відновлення',
      step: '+${_percent(PrototypeSimulation.regenSpeedPerLevel, 1)} / рів.',
      total: _supplyRate,
    ),
  ],
};

String _flat(num value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

String _percent(double share, int digits) =>
    '${(share * 100).toStringAsFixed(digits)}%';

/// The buffs a part shows at [generation] -- which is all it has grown.
List<ArmBuff> buffsOf(ArmPart part, int generation) => [
  for (final buff in armBuffs[part]!)
    if (buff.fromGeneration <= generation) buff,
];

/// The buffs a generation opens, and nothing carried over from before it.
List<ArmBuff> buffsOpenedBy(ArmPart part, int generation) => [
  for (final buff in armBuffs[part]!)
    if (buff.fromGeneration == generation) buff,
];

/// How a generation is written wherever one is named.
String markName(int generation) =>
    const ['Mk I', 'Mk II', 'Mk III', 'Mk IV', 'Mk V'][generation];

String _bitPower(PrototypeSimulation sim) {
  final gained = PrototypeSimulation.basePowerPerLevel * sim.bitLevel.value;
  return '+${BigDouble.fromNum(gained)}';
}

String _bitMinRegolith(PrototypeSimulation sim) =>
    '×${_growth(PrototypeSimulation.minRegolithGrowth, sim.bitLevel.value)}';

String _drivePierce(PrototypeSimulation sim) {
  final gained =
      PrototypeSimulation.piercePerLevel * sim.driveLevel.value * 100;
  return '+${gained.toStringAsFixed(3)}%';
}

String _driveMaxRegolith(PrototypeSimulation sim) =>
    '×${_growth(PrototypeSimulation.maxRegolithGrowth, sim.driveLevel.value)}';

String _supplyCap(PrototypeSimulation sim) =>
    '+${PrototypeSimulation.energyPerCapLevel * sim.supplyLevel.value}';

String _supplyRate(PrototypeSimulation sim) {
  final gained =
      PrototypeSimulation.regenSpeedPerLevel * sim.supplyLevel.value * 100;
  return '+${gained.toStringAsFixed(1)}%';
}

/// A compounding buff's standing total. It outgrows a plain double fast, so
/// it is carried in the game's own number type all the way to the string.
BigDouble _growth(double rate, int level) =>
    BigDouble.fromNum(rate).pow(level.toDouble());
