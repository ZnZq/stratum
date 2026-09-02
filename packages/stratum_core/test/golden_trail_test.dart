import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/golden_trail.dart';

/// The refactoring safety net: a fixed script of play must land on
/// exactly the state it landed on before the core was taken apart --
/// depth, every shelf, every roll stream. A single shifted roll or a
/// payout moved by a rounding shows up here as a diff, not as a player's
/// complaint.
///
/// Regenerate ON PURPOSE only, after a mechanic changes by decision:
/// `dart run tool/golden_trail.dart > test/golden/trail.json`.
void main() {
  test('the golden trail reproduces to the bit', () {
    final expected = jsonDecode(
      File('test/golden/trail.json').readAsStringSync(),
    );
    final actual = jsonDecode(jsonEncode(goldenSnapshot(goldenTrail())));
    expect(actual, expected);
  });
}
