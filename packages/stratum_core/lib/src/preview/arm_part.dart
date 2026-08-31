/// The three parts of the manipulator arm the player upgrades.
///
/// Named after the hardware rather than the stat, because a part carries
/// several buffs at once and grows more of them as it evolves.
enum ArmPart {
  /// What the arm strikes with: the blow's own power, and the floor of what
  /// it brings back.
  bit,

  /// What drives the bit into the face: how deep a blow bites into what is
  /// still standing, and the ceiling of the haul.
  drive,

  /// The pack in the shoulder: how many blows are in the magazine and how
  /// fast it refills.
  supply,
}
