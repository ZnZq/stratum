import 'package:flutter/widgets.dart';

import '../../game.dart';

import 'dart:async';

/// The rock face takes the blows.
///
/// A tap anywhere on the borehole is one strike; holding repeats them, and
/// the repeats wind up -- a held finger digs faster the longer it stays down,
/// so committing to a dig feels like leaning into it. It draws nothing: the
/// result shows in the rock and on the energy plate.
class StrikeZone extends StatefulWidget {
  const StrikeZone({required this.game, super.key});

  final Game game;

  @override
  State<StrikeZone> createState() => StrikeZoneState();
}

class StrikeZoneState extends State<StrikeZone> {
  Timer? _repeat;

  /// The wind-up: the first repeat lands after [_startMs], every following
  /// one comes [_stepMs] sooner, down to [_floorMs]. Release resets it.
  static const int _startMs = 200;
  static const int _floorMs = 100;
  static const int _stepMs = 10;

  int _intervalMs = _startMs;

  void _down() {
    widget.game.strike();
    _intervalMs = _startMs;
    _schedule();
  }

  void _schedule() {
    _repeat?.cancel();
    _repeat = Timer(Duration(milliseconds: _intervalMs), () {
      widget.game.strike();
      if (_intervalMs > _floorMs) {
        _intervalMs -= _stepMs;
        if (_intervalMs < _floorMs) _intervalMs = _floorMs;
      }
      _schedule();
    });
  }

  void _up() {
    _repeat?.cancel();
    _repeat = null;
    _intervalMs = _startMs;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // The rock is the game's biggest button, so the mouse says so.
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
