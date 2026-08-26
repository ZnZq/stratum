import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// Every drill the player owns, and where they are upgraded.
///
/// Off the mine screen on purpose: the borehole is for watching, and a
/// shopping list sitting under it competes with the thing it pays for. One
/// card per drill type; the locked cards below are the ladder the restart
/// tree will open.
class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({required this.game, super.key});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final milestone = sim.nextMilestone;

    return ColoredBox(
      color: Palette.scene,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
        children: [
          _Total(game: game),
          const SizedBox(height: 14),
          Text(
            'ВАШІ БУРИ',
            style: AppText.body(
              8.5,
              weight: FontWeight.w700,
              color: Palette.tech,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          _DrillCard(
            icon: Ti.grain,
            colour: Palette.ore,
            name: 'Реголітовий бур',
            note: 'базовий · добуває реголіт щоциклу',
            children: [
              // Two levers that multiply into one number. Each row previews only
              // its own lever; their product is the total above, so the same
              // figure is not printed three times.
              UpgradeRow(
                label: 'бурів',
                value: '${sim.drills.value}',
                note: milestone == null ? null : '×2 на $milestone',
                preview: '${sim.drills.value} → ${sim.drills.value + 1}',
                cost: '${sim.drillCost.value}',
                affordable: sim.canBuyDrill,
                onBuy: game.buyDrill,
              ),
              const SizedBox(height: 9),
              UpgradeRow(
                label: 'потужність бура',
                value: '${sim.perDrillPower.value}',
                note: 'рівень ${sim.drillPowerLevel.value}',
                preview:
                    '${sim.perDrillPower.value} → '
                    '${sim.perDrillPowerWith(sim.drillPowerLevel.value + 1)}',
                cost: '${sim.powerUpgradeCost.value}',
                affordable: sim.canBuyPowerUpgrade,
                onBuy: game.buyPowerUpgrade,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'МАЙБУТНІ БУРИ',
            style: AppText.body(
              8.5,
              weight: FontWeight.w700,
              color: Palette.textFaint,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          for (final locked in const [
            (ResourceId.cuprite, 'Купритовий бур'),
            (ResourceId.ferrite, 'Феритовий бур'),
            (ResourceId.silicite, 'Силіцитовий бур'),
            (ResourceId.crystals, 'Кристалічний бур'),
          ])
            _LockedDrill(id: locked.$1, name: locked.$2),
        ],
      ),
    );
  }
}

/// One owned drill type: its face, and the levers that grow it.
class _DrillCard extends StatelessWidget {
  const _DrillCard({
    required this.icon,
    required this.colour,
    required this.name,
    required this.note,
    required this.children,
  });

  final IconData icon;
  final Color colour;
  final String name;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.bar,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Palette.line),
                ),
                child: Icon(icon, size: 15, color: colour),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppText.body(
                        12,
                        weight: FontWeight.w700,
                        color: Palette.text,
                      ),
                    ),
                    Text(
                      note,
                      style: AppText.body(9.5, color: Palette.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// A drill the restart tree has not opened yet.
class _LockedDrill extends StatelessWidget {
  const _LockedDrill({required this.id, required this.name});

  final ResourceId id;
  final String name;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[id]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Opacity(
        opacity: 0.5,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.bar,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Palette.lineBar),
              ),
              child: Icon(style.icon, size: 15, color: style.colour),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppText.body(
                      12,
                      weight: FontWeight.w700,
                      color: Palette.textDim,
                    ),
                  ),
                  Text(
                    'добуватиме ${style.label.toLowerCase()} · '
                    'відкривається деревом перезапуску',
                    style: AppText.body(9.5, color: Palette.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The number the two levers make, spelled out as the product it is.
class _Total extends StatelessWidget {
  const _Total({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ЗАГАЛЬНА СИЛА',
            style: AppText.body(
              8.5,
              weight: FontWeight.w700,
              color: Palette.tech,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${sim.power.value}',
            style: AppText.display(
              26,
              weight: FontWeight.w700,
              color: Palette.gold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${sim.drills.value} бурів × ${sim.perDrillPower.value} '
            'за тік',
            style: AppText.display(11.5, color: Palette.textMuted),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Row(
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
      ),
    );
  }
}

/// A button that dips when pressed.
///
/// The callbacks are always non-null and the enabled state is carried
/// separately: swapping a gesture recognizer in and out mid-build is what set
/// off `setState() called during build` the first time round.
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
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool _down = false;

  void _setDown(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.onTap == null ? Palette.lineBar : Palette.line,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
