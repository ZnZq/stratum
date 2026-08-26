import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'ui/game_shell.dart';
import 'ui/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Every number in the interface goes through this unless a widget asks for
  // something else, so the suffix table is set once here.
  NumberStyle.global = NumberStyle.compact;

  runApp(const StratumApp());
}

class StratumApp extends StatelessWidget {
  const StratumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'STRATUM',
      color: Palette.page,
      // The game is one layout for touch and desktop, so the mouse must be
      // able to do what a finger does: drag any wheel-scrollable area.
      builder: (context, _) => ScrollConfiguration(
        behavior: const _DragEverywhereScrollBehavior(),
        child: const GameShell(),
      ),
      textStyle: AppText.body(14),
    );
  }
}

class _DragEverywhereScrollBehavior extends ScrollBehavior {
  const _DragEverywhereScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
