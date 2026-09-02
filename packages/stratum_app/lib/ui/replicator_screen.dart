import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'resource_style.dart';
import 'tokens.dart';
import 'phase_servo.dart';

/// The replicators: one machine per crafted resource, each running its
/// own print CYCLES once calibrated. Rows are READOUTS, not buttons --
/// the layered print and both upgrade tracks live inside them.
class ReplicatorScreen extends StatelessWidget {
  const ReplicatorScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: ListView(
        children: [
          for (final id in PrototypeSimulation.replicableIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ReplicatorRow(game: game, id: id),
            ),
        ],
      ),
    );
  }
}

/// One machine: the print scene, its cycle readout, and both tracks.
class _ReplicatorRow extends StatelessWidget {
  const _ReplicatorRow({required this.game, required this.id});

  final Game game;
  final ResourceId id;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final style = resourceStyles[id]!;
    final unlocked = sim.replicatorUnlockedOf(id).value;
    return HudPlate(
      cut: 6,
      fill: Palette.well.withValues(alpha: 0.5),
      edge: style.colour.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      child: _row(sim, style, unlocked),
    );
  }

  static String _seconds(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  static String _rate(BigDouble value) => value.toDouble() < 10
      ? value.toDouble().toStringAsFixed(2)
      : value.toString();

  /// The one row both states share: the print scene, the cycle
  /// readouts, and whichever buttons the state carries. A locked
  /// machine shows the very same face with the animation held still.
  Widget _row(PrototypeSimulation sim, ResourceStyle style, bool unlocked) {
    final name = Text(
      style.label.toUpperCase(),
      style: AppText.body(
        9.5,
        weight: FontWeight.w800,
        letterSpacing: 1,
        color: style.colour,
      ),
    );
    final row = Row(
      crossAxisAlignment: unlocked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _PrinterScene(
            game: game,
            id: id,
            colour: style.colour,
            active: unlocked,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: unlocked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '+${_rate(sim.replicatorPerSecondOf(id))}',
                            style: AppText.display(
                              11,
                              weight: FontWeight.w700,
                              color: Palette.tech,
                            ),
                          ),
                          TextSpan(
                            text: ' / с',
                            style: AppText.display(8, color: Palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _fact(
                          'цикл',
                          _seconds(sim.replicatorSeconds(id)),
                          ' с',
                        ),
                        const SizedBox(width: 14),
                        _fact('за цикл', '+${sim.replicatorYieldOf(id)}', ''),
                      ],
                    ),
                  ],
                )
              : Align(alignment: Alignment.centerLeft, child: name),
        ),
        const SizedBox(width: 8),
        if (unlocked)
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _track(
                  sim: sim,
                  benefit: 'ЦИКЛ → ${_seconds(_nextSeconds(sim))} с',
                  cost: sim.replicatorSpeedCost(id),
                  quant: sim.replicatorSpeedQuant(id),
                  enabled: sim.canUpgradeReplicatorSpeed(id),
                  buy: () => sim.upgradeReplicatorSpeed(id),
                ),
                const SizedBox(height: 4),
                _track(
                  sim: sim,
                  benefit:
                      'ВИХІД +${PrototypeSimulation.replicatorAmountStep(id)}',
                  cost: sim.replicatorAmountCost(id),
                  quant: sim.replicatorAmountQuant(id),
                  enabled: sim.canUpgradeReplicatorAmount(id),
                  buy: () => sim.upgradeReplicatorAmount(id),
                ),
              ],
            ),
          )
        else
          _calibrate(sim),
      ],
    );
    // The stretch that lets the toll button fill the row's height needs
    // IntrinsicHeight -- rule seven of the foundations.
    return unlocked ? row : IntrinsicHeight(child: row);
  }

  /// One small labelled reading of the board: value big, unit small.
  Widget _fact(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.display(
            6,
            letterSpacing: 0.6,
            color: Palette.textFaint,
          ),
        ),
        const SizedBox(height: 1),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppText.display(
                  9,
                  weight: FontWeight.w700,
                  color: Palette.textMuted,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: unit,
                  style: AppText.display(6.5, color: Palette.textFaint),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The cycle time one speed level from now -- the button's promise,
  /// from the machine's own formula.
  double _nextSeconds(PrototypeSimulation sim) =>
      PrototypeSimulation.replicatorSecondsAt(
        id,
        sim.replicatorSpeedOf(id).value + 1,
      );

  /// One icon-and-figure price, the shared word of every button here.
  Widget _price(String figure, ResourceId coin, bool lit, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          figure,
          style: AppText.display(
            size,
            weight: FontWeight.w700,
            color: lit ? Palette.gold : Palette.textFaint,
          ),
        ),
        const SizedBox(width: 3),
        ResourceIcon(coin, size: size, colour: lit ? null : Palette.textFaint),
      ],
    );
  }

  /// The unlock: no word, just the two prices the machine asks.
  Widget _calibrate(PrototypeSimulation sim) {
    final affordable = sim.canUnlockReplicator(id);
    return HudButton(
      onTap: affordable
          ? () {
              if (sim.unlockReplicator(id)) game.pokeListeners();
            }
          : null,
      holdRepeat: true,
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _price(
              PrototypeSimulation.replicatorUnlockCost(id).toStringAsFixed(0),
              id,
              affordable,
              8.5,
            ),
            const SizedBox(height: 3),
            _price(
              PrototypeSimulation.replicatorUnlockQuant(id).toStringAsFixed(0),
              ResourceId.quantonium,
              affordable,
              8.5,
            ),
          ],
        ),
      ),
    );
  }

  /// A track button in two storeys: the benefit above, prices below.
  Widget _track({
    required PrototypeSimulation sim,
    required String benefit,
    required BigDouble cost,
    required BigDouble quant,
    required bool enabled,
    required bool Function() buy,
  }) {
    return HudButton(
      onTap: enabled
          ? () {
              if (buy()) game.pokeListeners();
            }
          : null,
      holdRepeat: true,
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            benefit,
            style: AppText.display(
              8,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
              color: enabled ? Palette.text : Palette.textFaint,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _price('$cost', id, enabled, 7),
              const SizedBox(width: 7),
              _price('$quant', ResourceId.quantonium, enabled, 7),
            ],
          ),
        ],
      ),
    );
  }
}

/// The layered print (owner's pick, Р5): the copy grows bottom-up
/// inside a small chamber, a printhead sweeps along the current print
/// line, and a finished copy flashes once. The scene runs its OWN
/// smooth phase and servos it to the core's cycle fraction only when
/// the core settles -- the conveyor's phase-loop rule.
class _PrinterScene extends StatefulWidget {
  const _PrinterScene({
    required this.game,
    required this.id,
    required this.colour,
    required this.active,
  });

  final Game game;
  final ResourceId id;
  final Color colour;

  /// A locked machine keeps the same face with the animation held.
  final bool active;

  @override
  State<_PrinterScene> createState() => _PrinterSceneState();
}

class _PrinterSceneState extends State<_PrinterScene>
    with SingleTickerProviderStateMixin {
  static const double _side = 52;
  static const double _icon = 24;
  static const double _bed = 6;
  static const double _ceiling = 6;

  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);

  Duration _lastElapsed = Duration.zero;
  final PhaseServo _servo = PhaseServo(settleSeconds: 0.5);
  double _flash = 0;

  @override
  void initState() {
    super.initState();
    // Mount snaps straight to the core's truth -- no chase on entry.
    _servo.snap(widget.game.sim.replicatorFractionOf(widget.id).value);
    _ticker = createTicker(_tick);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(_PrinterScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _servo.snap(widget.game.sim.replicatorFractionOf(widget.id).value);
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final gap = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final raw = gap.inMicroseconds / 1e6;
    final dt = clampFrameDelta(gap).inMicroseconds / 1e6;
    final sim = widget.game.sim;
    final wrapped = _servo.advance(
      dt: dt,
      raw: raw,
      unitSeconds: sim.replicatorSeconds(widget.id),
      core: sim.replicatorFractionOf(widget.id).value,
    );
    // A frame hole snaps the phase and drops the beat with it: nothing
    // that nobody watched gets celebrated late.
    if (raw > _servo.gapSeconds) {
      _flash = 0;
    } else {
      if (wrapped) _flash = 1;
      _flash = math.max(0, _flash - dt * 2.5);
    }
    _clock.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _side,
      height: _side,
      child: ValueListenableBuilder<double>(
        valueListenable: _clock,
        builder: (context, time, _) {
          final p = _servo.phase.clamp(0.0, 1.0);
          // The copy sits centred; the head sweeps the WHOLE chamber,
          // floor to ceiling, so the icon prints along the middle leg.
          const bottom = (_side - _icon) / 2;
          const travel = _side - _bed - _ceiling;
          final printed = ((travel * p - (bottom - _bed)) / _icon).clamp(
            0.0,
            1.0,
          );
          return Stack(
            children: [
              CustomPaint(
                size: const Size(_side, _side),
                painter: _ChamberPainter(
                  colour: widget.colour,
                  phase: p,
                  time: time,
                  flash: _flash,
                  iconSide: _icon,
                ),
              ),
              Positioned(
                left: (_side - _icon) / 2,
                bottom: bottom,
                width: _icon,
                height: _icon,
                child: Opacity(
                  opacity: 0.14,
                  child: ResourceIcon(widget.id, size: _icon),
                ),
              ),
              Positioned(
                left: (_side - _icon) / 2,
                bottom: bottom,
                width: _icon,
                height: _icon,
                child: ClipRect(
                  clipper: _BottomSlice(printed),
                  child: ResourceIcon(widget.id, size: _icon),
                ),
              ),
              if (_flash > 0)
                Positioned(
                  left: (_side - _icon) / 2,
                  bottom: bottom,
                  width: _icon,
                  height: _icon,
                  child: Opacity(
                    opacity: _flash * 0.55,
                    child: ResourceIcon(
                      widget.id,
                      size: _icon,
                      colour: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              Positioned(
                top: 7,
                right: 8,
                child: Text(
                  '${(p * 100).round()}%',
                  style: AppText.display(6.5, color: Palette.textFaint),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps the printed share of the copy: the bottom [fraction] of it.
class _BottomSlice extends CustomClipper<Rect> {
  const _BottomSlice(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    size.height * (1 - fraction),
    size.width,
    size.height * fraction,
  );

  @override
  bool shouldReclip(_BottomSlice oldClipper) => oldClipper.fraction != fraction;
}

/// The chamber around the copy: frame, print bed, and the sweeping
/// printhead riding the current print line.
class _ChamberPainter extends CustomPainter {
  const _ChamberPainter({
    required this.colour,
    required this.phase,
    required this.time,
    required this.flash,
    required this.iconSide,
  });

  final Color colour;
  final double phase;
  final double time;
  final double flash;
  final double iconSide;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colour.withValues(alpha: 0.25);

    // The chamber: two side posts and the print bed they stand on.
    final bedY = size.height - 6;
    canvas.drawLine(Offset(4, 6), Offset(4, bedY), line);
    canvas.drawLine(
      Offset(size.width - 4, 6),
      Offset(size.width - 4, bedY),
      line,
    );
    canvas.drawLine(
      Offset(2, bedY),
      Offset(size.width - 2, bedY),
      Paint()
        ..strokeWidth = 1.4
        ..color = colour.withValues(alpha: 0.45),
    );

    // The printhead rides the line being printed right now: the full
    // run from the chamber's floor to its ceiling.
    final headY = bedY - (bedY - 6) * phase;
    final sweep = math.sin(time * 7) * (size.width / 2 - 9);
    final headX = size.width / 2 + sweep;
    canvas.drawLine(
      Offset(6, headY),
      Offset(size.width - 6, headY),
      Paint()
        ..strokeWidth = 0.8
        ..color = colour.withValues(alpha: 0.3),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(headX, headY), width: 5, height: 3),
      Paint()..color = colour.withValues(alpha: 0.9),
    );
    // A faint deposit glow under the nozzle.
    canvas.drawCircle(
      Offset(headX, headY + 1.5),
      2.4,
      Paint()..color = colour.withValues(alpha: 0.25),
    );

    if (flash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: flash * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(_ChamberPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.time != time ||
      oldDelegate.flash != flash;
}
