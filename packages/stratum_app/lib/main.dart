import 'package:flutter/material.dart';

void main() {
  runApp(const StratumApp());
}

/// Тимчасова заглушка. Екран Бура (сцена страт, тік-пульс, форсаж) з'явиться
/// після того, як `stratum_core` отримає тік-рушій — див. план порту в CLAUDE.md.
class StratumApp extends StatelessWidget {
  const StratumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STRATUM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('STRATUM', style: TextStyle(letterSpacing: 6))),
      ),
    );
  }
}
