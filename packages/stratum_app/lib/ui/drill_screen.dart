import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'floating_number.dart';
import 'tabler_icons.dart';
import 'tick_ring.dart';
import 'tokens.dart';

const double _layerHeight = 96;

/// How many layers sit above and below the one being drilled.
const int _layersAbove = 2;
const int _layersBelow = 4;

/// Where cracks sit on a layer and how they lie, transcribed from the prototype
/// so damage reads the same way. Positions are percentages of the layer.
const List<({double x, double y, double turn, double length})> _cracks = [
  (x: 16, y: 20, turn: 62, length: 52),
  (x: 52, y: 44, turn: -34, length: 66),
  (x: 30, y: 64, turn: 10, length: 56),
  (x: 68, y: 14, turn: 78, length: 44),
  (x: 8, y: 46, turn: -64, length: 48),
  (x: 44, y: 8, turn: 24, length: 70),
  (x: 78, y: 56, turn: -12, length: 42),
];

class DrillScreen extends StatelessWidget {
  const DrillScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DepthReadout(game: game),
          const SizedBox(height: 10),
          // The scene takes whatever height is left. A taller window shows more
          // strata rather than more emptiness, which is the whole reason the
          // desktop window is phone-shaped instead of phone-sized.
          Expanded(child: _Scene(game: game)),
          const SizedBox(height: 10),
          _DrillCard(game: game),
          const SizedBox(height: 10),
          _ForcingCard(game: game),
          const SizedBox(height: 10),
          const _RestartButton(),
        ],
      ),
    );
  }
}

class _DepthReadout extends StatelessWidget {
  const _DepthReadout({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'глибина · симуляція ${game.sim.restarts.value + 1}',
          style: AppText.eyebrow(),
        ),
        Text(
          '${game.sim.layer.value.big.toString(NumberStyle.integer)} м',
          style: AppText.display(38, color: Palette.gold, height: 1.12),
        ),
      ],
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: game.sim.layer.value.toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, position, _) =>
            _build(context, constraints.maxHeight, position),
      ),
    );
  }

  Widget _build(BuildContext context, double height, double position) {
    final sim = game.sim;
    final current = sim.layer.value;

    // The window of rendered layers follows the animated position, and the
    // camera offset is measured from the first of them. As the position crosses
    // an integer the window steps down by one layer and the offset steps back
    // by exactly one layer height, so the two cancel and the descent stays
    // continuous instead of restarting every metre.
    final anchor = position.floor();
    final first = math.max(0, anchor - _layersAbove);
    final cameraY = 120 - (position - first) * _layerHeight;

    final below = math.max(
      _layersBelow,
      ((height - 120) / _layerHeight).ceil() + 1,
    );

    final hpFraction = (sim.layerHp.value / sim.layerHpMax.value)
        .toDouble()
        .clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.scene,
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // Applied straight, with no tween of its own: cameraY steps by a
              // whole layer at each crossing, and that step is exactly what the
              // shifted window of layers cancels out. Easing it would undo the
              // cancellation and make the descent lurch.
              child: Transform.translate(
                offset: Offset(0, cameraY),
                child: Column(
                  children: [
                    for (var i = first; i <= current + below; i++)
                      SizedBox(
                        height: _layerHeight,
                        child: _LayerTile(
                          layer: i,
                          isCurrent: i == current,
                          isPast: i < current,
                          hpFraction: hpFraction,
                          cyclesLabel: '~${sim.cyclesToBreak.value} циклів',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const _DrillColumn(),
            _DrillHead(game: game),
            _Flash(
              trigger: game.breakFlashes,
              duration: const Duration(milliseconds: 550),
              peak: 0.85,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80FFD782), Color(0x14EF9F27)],
                ),
              ),
            ),
            _Flash(
              trigger: game.criticalFlashes,
              duration: const Duration(milliseconds: 500),
              peak: 1,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.36),
                  radius: 0.65,
                  colors: [Color(0x80EF9F27), Color(0x00EF9F27)],
                ),
              ),
            ),
            _FloatLayer(game: game),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RaceFooter(game: game),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.layer,
    required this.isCurrent,
    required this.isPast,
    required this.hpFraction,
    required this.cyclesLabel,
  });

  final int layer;
  final bool isCurrent;
  final bool isPast;
  final double hpFraction;
  final String cyclesLabel;

  @override
  Widget build(BuildContext context) {
    final thick = PrototypeSimulation.isThick(layer);
    final fill = thick ? Palette.thickLayer : Strata.fillFor(layer);
    final opacity = isPast ? 0.38 : (isCurrent ? 1.0 : 0.74);
    final damage = 1 - hpFraction;

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
          border: Border(
            top: BorderSide(
              color: thick ? Palette.gold : const Color(0x8C000000),
              width: 2,
            ),
          ),
        ),
        child: Stack(
          children: [
            if (isCurrent)
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (var i = 0; i < _cracks.length; i++)
                      if ((damage * 7 - i).clamp(0.0, 1.0) > 0.03)
                        _Crack(
                          spec: _cracks[i],
                          width: constraints.maxWidth,
                          opacity: (damage * 7 - i).clamp(0.0, 1.0),
                        ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          thick
                              ? '${layer + 1} м · ТОВСТИЙ ШАР'
                              : '${layer + 1}-й метр · ${Strata.nameFor(layer)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(11.5,
                              weight: FontWeight.w700, shadows: true),
                        ),
                      ),
                      Text(
                        '${layer + 1} м',
                        style:
                            AppText.display(10, color: const Color(0x8CE8E9EE)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thick
                        ? 'гарантія: всі ресурси ×5'
                        : 'щільність ${PrototypeSimulation.densityAt(layer)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(10, color: const Color(0x9EE8E9EE)),
                  ),
                ],
              ),
            ),
            if (isCurrent) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 4,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: hpFraction,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(colors: [Palette.amber, Palette.gold]),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  cyclesLabel,
                  style:
                      AppText.display(10.5, color: Palette.gold, shadows: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Crack extends StatelessWidget {
  const _Crack({
    required this.spec,
    required this.width,
    required this.opacity,
  });

  final ({double x, double y, double turn, double length}) spec;
  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: spec.x / 100 * width,
      top: spec.y / 100 * _layerHeight,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: spec.turn * math.pi / 180,
          child: Container(
            width: spec.length,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [Color(0xE6000000), Color(0x33000000)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrillColumn extends StatelessWidget {
  const _DrillColumn();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 28,
        height: 122,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060709), Color(0xFF0A0B0F), Color(0x4DEF9F27)],
            stops: [0, 0.6, 1],
          ),
        ),
      ),
    );
  }
}

class _DrillHead extends StatelessWidget {
  const _DrillHead({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final forcing = game.isForcing;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TickRing(engine: game.drill, spinning: forcing),
              ),
            ),
            Align(
              alignment: const Alignment(0.42, -1),
              child: Padding(
                padding: const EdgeInsets.only(top: 58),
                child: Text(
                  forcing ? 'тік 1.0 с' : 'тік 4.0 с',
                  style: AppText.display(
                    10.5,
                    color: forcing ? Palette.gold : Palette.textMuted,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 104),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 18,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Palette.edge, Palette.textMuted],
                        ),
                      ),
                    ),
                    ClipPath(
                      clipper: _BitClipper(),
                      child: Container(
                        width: 22,
                        height: 14,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Palette.gold, Palette.amber],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(_BitClipper oldClipper) => false;
}

class _FloatLayer extends StatelessWidget {
  const _FloatLayer({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final float in game.floats)
              FloatingNumberView(
                key: ValueKey(float.id),
                number: float,
                onDone: () => game.retireFloat(float.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _RaceFooter extends StatelessWidget {
  const _RaceFooter({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final separator = Text(' · ', style: AppText.display(11, color: Palette.edge));

    return Container(
      height: 28,
      color: const Color(0xDB08090C),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('щільність ${sim.layerHpMax.value}',
              style: AppText.display(11, color: Palette.textDim)),
          separator,
          Text('сила ${sim.power.value}',
              style: AppText.display(11, color: Palette.gold)),
          separator,
          Text('~${sim.cyclesToBreak.value} циклів',
              style: AppText.display(11, color: Palette.textMuted)),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final milestone = sim.nextMilestone;
    final affordable = sim.canBuyDrill;

    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Бури: ', style: AppText.body(12)),
                    Text('${sim.drills.value}',
                        style: AppText.display(12,
                            weight: FontWeight.w700, color: Palette.gold)),
                    if (milestone != null)
                      Flexible(
                        child: Text(' · ×2 сили на $milestone',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppText.body(10.5, color: Palette.textMuted)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'сила ${sim.power.value} → ${sim.powerAt(sim.drills.value + 1)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(10.5, color: Palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: affordable ? 1 : 0.4,
            child: _PressButton(
              onTap: affordable ? game.buyDrill : null,
              background: Palette.goldWell,
              child: Text(
                '+бур · ${sim.drillCost.value} руди',
                style: AppText.body(12,
                    weight: FontWeight.w700, color: Palette.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForcingCard extends StatelessWidget {
  const _ForcingCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final charge = sim.charge.value;
    final forcing = game.isForcing;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('заряд форсажу',
                  style: AppText.body(11, color: Palette.textMuted)),
              Text('$charge',
                  style: AppText.display(11,
                      weight: FontWeight.w700, color: Palette.gold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: Palette.scene,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (charge / PrototypeSimulation.chargeCap).clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(colors: [Palette.amber, Palette.gold]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Listener(
            onPointerDown: (_) => game.startForcing(),
            onPointerUp: (_) => game.stopForcing(),
            onPointerCancel: (_) => game.stopForcing(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: forcing ? Palette.gold : Palette.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Ti.flame, size: 16, color: Palette.goldInk),
                  const SizedBox(width: 8),
                  Text(
                    forcing
                        ? 'Форсаж активний · тік 1 с'
                        : 'Форсаж (утримуй) · тік 1 с',
                    style: AppText.body(13.5,
                        weight: FontWeight.w800, color: Palette.goldInk),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestartButton extends StatelessWidget {
  const _RestartButton();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Palette.capsuleTree,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ti.refresh, size: 16, color: Palette.capsuleInk),
            const SizedBox(width: 8),
            Text('Перезапуск · чекає на баланс',
                style: AppText.body(13.5,
                    weight: FontWeight.w800, color: Palette.capsuleInk)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.card,
        border: Border.all(color: Palette.lineSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _PressButton extends StatefulWidget {
  const _PressButton({
    required this.onTap,
    required this.background,
    required this.child,
  });

  final VoidCallback? onTap;
  final Color background;
  final Widget child;

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _down = false;

  void _setDown(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Every callback stays non-null even while the button is unaffordable.
      // Handing GestureDetector a different set of callbacks makes it swap the
      // recognizer, and disposing a recognizer fires onTapCancel synchronously
      // inside didUpdateWidget -- which is during build, where setState is not
      // allowed. Affordability flips the moment ore reaches the price, so that
      // swap would happen in the middle of ordinary play.
      onTapDown: (_) => _setDown(widget.onTap != null),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: () => widget.onTap?.call(),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}


/// A one-shot wash of colour over the scene, replayed whenever [trigger] moves.
///
/// The prototype signals a critical and a broken layer with a brief overlay
/// rather than a lasting state, so this plays and leaves nothing behind.
class _Flash extends StatefulWidget {
  const _Flash({
    required this.trigger,
    required this.duration,
    required this.peak,
    required this.decoration,
  });

  final ValueListenable<int> trigger;
  final Duration duration;
  final double peak;
  final Decoration decoration;

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_play);
  }

  void _play() => _controller.forward(from: 0);

  @override
  void dispose() {
    widget.trigger.removeListener(_play);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            // Snaps in over the first fifth, then falls away.
            final opacity =
                t < 0.2 ? t / 0.2 * widget.peak : (1 - t) / 0.8 * widget.peak;
            return Opacity(opacity: opacity.clamp(0, 1), child: child);
          },
          child: DecoratedBox(decoration: widget.decoration),
        ),
      ),
    );
  }
}
