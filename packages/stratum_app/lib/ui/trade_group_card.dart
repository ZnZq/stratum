import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'resource_style.dart';
import 'tokens.dart';
import 'resource_icon.dart';

/// The manual sale, filling whatever the share picker leaves.
///
/// The figure changes every tick, and a button sized by its own label would
/// drag the share picker around with it. The row hands it the leftover width
/// instead, and the label shrinks to fit rather than the box growing.
class _SellButton extends StatelessWidget {
  const _SellButton({required this.pay, required this.onTap});

  final BigDouble pay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HudButton(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          pay.isZero ? 'ПРОДАТИ' : 'ПРОДАТИ · +$pay',
          maxLines: 1,
          style: AppText.body(
            9,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
            color: onTap == null ? Palette.textFaint : Palette.gold,
          ),
        ),
      ),
    );
  }
}

/// Whether the sweep takes this position. Off is a routing choice, not a
/// state of the position -- the row around it keeps full colour.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.onTap, this.label});

  final bool on;
  final VoidCallback onTap;

  /// What the switch routes, said beside it: a bare toggle in a card full
  /// of controls does not say which of them it governs.
  final String? label;

  @override
  Widget build(BuildContext context) {
    // The knob is chamfered like its track and inset from the corners: a
    // square knob flush against the cut read as sticking out of the shape.
    final track = HudPlate(
      cut: 5,
      fill: on ? Palette.goldWell : Palette.shell,
      edge: on ? Palette.amber : Palette.lineBar,
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        width: 28,
        height: 12,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 110),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: HudPlate(
            cut: 3.5,
            fill: on ? Palette.gold : Palette.line,
            child: const SizedBox(width: 11, height: 11),
          ),
        ),
      ),
    );
    return HudTap(
      onTap: onTap,
      // The film would flood the caption beside the track too; the cursor
      // already answers hover, and the knob answers the tap.
      wash: false,
      child: label == null
          ? track
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!.toUpperCase(),
                  style: AppText.body(
                    8,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: on ? Palette.gold : Palette.textFaint,
                  ),
                ),
                const SizedBox(width: 6),
                track,
              ],
            ),
    );
  }
}

class _SharePicker extends StatelessWidget {
  const _SharePicker({
    required this.sim,
    required this.id,
    required this.onChange,
  });

  final PrototypeSimulation sim;
  final ResourceId id;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    return HudChoice<int>(
      options: [
        for (final step in PrototypeSimulation.sellShares) (step, '$step%'),
      ],
      value: sim.sellShareOf(id).value,
      onPick: (step) => onChange(() => sim.sellShareOf(id).value = step),
      cut: 5,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
    );
  }
}

/// The grouped view: one card per family, the chosen member's settings on
/// top, the members as a picker row at the bottom.
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.sim,
    required this.label,
    required this.members,
    required this.group,
    required this.picked,
    required this.onPick,
    required this.onChange,
    super.key,
  });

  final PrototypeSimulation sim;

  /// The shelf's headline, e.g. 'РЕСУРСИ'.
  final String label;

  final List<ResourceId> members;

  /// The whole shelf's sweep switch.
  final Signal<bool> group;

  final ResourceId picked;
  final ValueChanged<ResourceId> onPick;
  final ValueChanged<VoidCallback> onChange;

  @override
  Widget build(BuildContext context) {
    final style = resourceStyles[picked]!;
    final selling = sim.sellingOf(picked).value;
    final pay = sim.sellYield(picked);
    // The card's edge answers "does this shelf pay?": grey when the group
    // is off or nothing in it is switched on.
    final live = members.any(sim.sellsInSweep);
    return HudBox(
      cut: 11,
      fill: Palette.bar.withValues(alpha: 0.6),
      edge: live ? Palette.gold.withValues(alpha: 0.55) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '$label · ${members.length}',
                style: AppText.body(
                  8.5,
                  weight: FontWeight.w700,
                  color: Palette.gold,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              // The shelf's own switch: it does NOT rewrite what each
              // position chose, so flipping it back restores the set-up.
              _Toggle(
                label: 'вся група',
                on: group.value,
                onTap: () => onChange(() => group.value = !group.value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              _Toggle(
                label: 'в продаж',
                on: selling,
                onTap: () =>
                    onChange(() => sim.sellingOf(picked).value = !selling),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Readouts, not a byline: the stock and the unit price are the two
          // numbers the sale is made of, and they deserve the house plate.
          // The left plate is HEADED BY THE POSITION ITSELF -- the amount
          // needs no word "склад" once the plate names what it counts.
          Row(
            children: [
              Expanded(
                child: HudStat(
                  label: style.label,
                  corners: const HudCorners(topLeft: true, bottomLeft: true),
                  value: '${sim.stock.amount(picked)}',
                  size: 13,
                  accent: style.colour,
                  colour: style.colour,
                  labelColour: style.colour,
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: HudStat(
                  label: 'ціна за 1',
                  align: CrossAxisAlignment.end,
                  corners: const HudCorners(topRight: true, bottomRight: true),
                  value: '${sim.sellPrice(picked)} кр',
                  size: 13,
                  accent: Palette.gold,
                  colour: Palette.gold,
                  labelColour: Palette.gold,
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SharePicker(sim: sim, id: picked, onChange: onChange),
              const SizedBox(width: 8),
              Expanded(
                child: _SellButton(
                  pay: pay,
                  onTap: pay.isZero
                      ? null
                      : () => onChange(() => sim.sellPosition(picked)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final id in members) ...[
                if (id != members.first) const SizedBox(width: 6),
                HudTap(
                  onTap: () => onPick(id),
                  corners: HudCorners.centred,
                  cut: 7,
                  // Chamfered, not rounded: the well sits on a HUD panel,
                  // and a rounded box was the app dialect leaking back in.
                  // Amber answers the EFFECTIVE question -- does this one
                  // actually go in the sweep: its own switch and the
                  // shelf's together.
                  child: HudPlate(
                    cut: 7,
                    fill: id == picked ? Palette.goldWell : Palette.shell,
                    edge: sim.sellsInSweep(id)
                        ? Palette.amber
                        : Palette.lineBar,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(child: ResourceIcon(id, size: 17)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
