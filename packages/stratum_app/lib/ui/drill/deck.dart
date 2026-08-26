/// The controls laid over the rock: readouts, upgrades and the handle that
/// folds them away.
library;

import 'package:flutter/widgets.dart';

import '../../game.dart';
import '../tabler_icons.dart';
import '../tokens.dart';

/// The rig's controls, laid on a deck that fades the rock out beneath them.
class Deck extends StatefulWidget {
  const Deck({required this.game, super.key});

  final Game game;

  @override
  State<Deck> createState() => DeckState();
}

class DeckState extends State<Deck> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final sim = game.sim;
    final milestone = sim.nextMilestone;
    final affordable = sim.canBuyDrill;

    return Listener(
      // Swallows presses that land on the deck but miss a control: the rock
      // behind it is the forcing handle, and it covers the whole screen.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x001E2834), Color(0xE61E2834), Color(0xF71E2834)],
            stops: [0, 0.42, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            14,
            22,
            14,
            AppMetrics.navBar + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeckHandle(
                expanded: _expanded,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              const SizedBox(height: 10),
              // The race the whole game is built on: rock hardness against bit
              // power, ending in the only number that answers "how long".
              Row(
                children: [
                  Stat(
                    label: 'щільність',
                    value: '${sim.layerHpMax.value}',
                    colour: Palette.textDim,
                  ),
                  const SizedBox(width: 18),
                  Stat(
                    label: 'сила',
                    value: '${sim.power.value}',
                    colour: Palette.gold,
                    note: '${sim.drills.value} × ${sim.perDrillPower.value}',
                  ),
                  const Spacer(),
                  Stat(
                    label: 'до пробиття',
                    value: '${sim.cyclesToBreak.value} циклів',
                    colour: Palette.textDim,
                    alignEnd: true,
                  ),
                ],
              ),
              // Two levers that multiply into one number. Each row previews
              // only its own lever; the product they make is the power readout
              // above, so the same figure is not printed three times.
              AnimatedSize(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 14),
                          UpgradeRow(
                            label: 'бурів',
                            value: '${sim.drills.value}',
                            note: milestone == null ? null : '×2 на $milestone',
                            preview:
                                '${sim.drills.value} → ${sim.drills.value + 1}',
                            cost: '${sim.drillCost.value}',
                            affordable: affordable,
                            onBuy: game.buyDrill,
                          ),
                          const SizedBox(height: 9),
                          UpgradeRow(
                            label: 'потужність бура',
                            value: '${sim.perDrillPower.value}',
                            note: 'рівень ${sim.drillPowerLevel.value}',
                            preview:
                                '${sim.perDrillPower.value} → ${sim.perDrillPowerWith(sim.drillPowerLevel.value + 1)}',
                            cost: '${sim.powerUpgradeCost.value}',
                            affordable: sim.canBuyPowerUpgrade,
                            onBuy: game.buyPowerUpgrade,
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grab bar that folds the upgrades away.
///
/// Collapsed, the deck keeps only what the player watches while drilling --
/// hardness, power, cycles left -- and hands the rest of the screen back to
/// the rock.
class DeckHandle extends StatelessWidget {
  const DeckHandle({required this.expanded, required this.onTap, super.key});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 1, color: const Color(0x337FD9C4)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Palette.shell,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x4D7FD9C4)),
              ),
              child: AnimatedRotation(
                turns: expanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                child: const CustomPaint(
                  size: Size(13, 7),
                  painter: ChevronPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChevronPainter extends CustomPainter {
  const ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.tech
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(ChevronPainter oldDelegate) => false;
}

class Stat extends StatelessWidget {
  const Stat({
    required this.label,
    required this.value,
    required this.colour,
    this.note,
    this.alignEnd = false,
    super.key,
  });

  final String label;
  final String value;
  final Color colour;
  final String? note;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.body(
            8.5,
            weight: FontWeight.w700,
            color: Palette.tech,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: AppText.display(14, weight: FontWeight.w600, color: colour),
        ),
        if (note != null)
          Text(note!, style: AppText.display(9.5, color: Palette.textFaint)),
      ],
    );
  }
}

/// One purchasable lever: what it stands at, what buying changes, the price.
class UpgradeRow extends StatelessWidget {
  const UpgradeRow({
    required this.label,
    required this.value,
    required this.preview,
    required this.cost,
    required this.affordable,
    required this.onBuy,
    this.note,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final String preview;
  final String cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppText.display(
                      19,
                      weight: FontWeight.w700,
                      color: Palette.gold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        8.5,
                        weight: FontWeight.w700,
                        color: Palette.tech,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      note!,
                      style: AppText.body(9.5, color: Palette.capsuleTree),
                    ),
                  ],
                ],
              ),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(11, color: Palette.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        PressButton(
          onTap: affordable ? onBuy : null,
          background: affordable ? Palette.goldWell : Palette.card,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Ti.stack2,
                size: 13,
                color: affordable ? Palette.gold : Palette.textFaint,
              ),
              const SizedBox(width: 6),
              Text(
                cost,
                style: AppText.body(
                  12,
                  weight: FontWeight.w700,
                  color: affordable ? Palette.gold : Palette.textFaint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PressButton extends StatefulWidget {
  const PressButton({
    required this.onTap,
    required this.background,
    required this.child,
    super.key,
  });

  final VoidCallback? onTap;
  final Color background;
  final Widget child;

  @override
  State<PressButton> createState() => PressButtonState();
}

class PressButtonState extends State<PressButton> {
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
