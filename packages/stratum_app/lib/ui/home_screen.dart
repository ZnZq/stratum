import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The shell: the game's name over its own drifting field.
///
/// What is left when the player steps out of every section. It holds nothing
/// to press on purpose -- everything that can be done has a tab of its own,
/// and a place with no job is what makes stepping out feel like stepping out
/// rather than like landing on another screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'STRATUM',
        style: AppText.display(
          22,
          weight: FontWeight.w700,
          color: const Color(0x667FD9C4),
          letterSpacing: 11,
        ),
      ),
    );
  }
}
