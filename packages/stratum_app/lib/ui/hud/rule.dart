import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The hairline: one pixel of panel line, wherever a list or a card seam
/// needs ruling off. Shared so five screens cannot each grow their own.
class HudRule extends StatelessWidget {
  const HudRule({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 1,
    width: double.infinity,
    child: ColoredBox(color: Palette.lineBar),
  );
}
