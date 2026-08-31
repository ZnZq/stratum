import 'package:flutter/widgets.dart';

import 'hud.dart';

/// The x1 / x10 / max selector every upgrade screen shares.
class BatchPicker extends StatelessWidget {
  const BatchPicker({required this.batch, required this.onPick, super.key});

  /// A batch of zero means "as many as the store can pay for".
  final int batch;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return HudChoice<int>(
      options: const [
        (1, '\u00d71'),
        (10, '\u00d710'),
        (0, '\u043c\u0430\u043a\u0441'),
      ],
      value: batch,
      onPick: onPick,
      cut: 5,
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
    );
  }
}
