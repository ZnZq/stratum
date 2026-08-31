import 'package:flutter/widgets.dart';

import '../game_icons.dart';
import '../navigation.dart';
import '../tokens.dart';

class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({required this.screen, super.key});

  final GameScreen screen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(screen.icon, size: 30),
          const SizedBox(height: 10),
          Text(screen.label.toUpperCase(), style: AppText.eyebrow()),
          const SizedBox(height: 6),
          Text(
            'наступний прохід',
            style: AppText.body(12, color: Palette.textFaint),
          ),
        ],
      ),
    );
  }
}
