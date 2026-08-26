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
      builder: (context, _) => const GameShell(),
      textStyle: AppText.body(14),
    );
  }
}
