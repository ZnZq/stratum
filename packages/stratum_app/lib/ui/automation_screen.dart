import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'clock_text.dart';
import 'game_icons.dart';
import 'hud.dart';
import 'resource_icon.dart';
import 'resource_style.dart';
import 'stat.dart';
import 'tokens.dart';

/// Automation: what runs on the player's behalf, one row each. A fresh
/// run has none; a locked row carries its price, an owned row opens its
/// own settings window on a tap. Settings that belong to a thing on
/// another screen (a position, an upgrade track) live there and are
/// named in the window.
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({required this.game, super.key});

  final Game game;

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  AutomationId? _open;

  static const List<({AutomationId id, String label, String note})> _rows = [
    (
      id: AutomationId.autoHands,
      label: 'Авто-руки',
      note: 'удар за інтервалом · реген повільніший, поки б\'ють',
    ),
    (
      id: AutomationId.autoSell,
      label: 'Авто-продаж',
      note: 'позиція продає свою частку за інтервалом, не нижче порогу',
    ),
    (
      id: AutomationId.autoRequests,
      label: 'Авто-запити',
      note: 'виконує запити, що не чіпають захищене і беруть не більше частки',
    ),
    (
      id: AutomationId.autoBuy,
      label: 'Авто-купівля',
      note: 'купує обрані треки за інтервалом, по N рівнів за цикл',
    ),
    (
      id: AutomationId.autoCraft,
      label: 'Авто-крафт',
      note: 'вільна лінія бере найдорожчий рецепт, який може годувати',
    ),
  ];

  Widget _settingsFor(AutomationId id) => switch (id) {
    AutomationId.autoHands => _StrikeSettings(game: widget.game),
    AutomationId.autoSell => _SellSettings(game: widget.game),
    AutomationId.autoRequests => _RequestSettings(game: widget.game),
    AutomationId.autoBuy => _BuySettings(game: widget.game),
    AutomationId.autoCraft => _CraftSettings(game: widget.game),
  };

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: ListView(
            children: [
              const Stat(label: 'автоматизації', rule: true),
              const SizedBox(height: 8),
              for (final row in _rows) ...[
                _AutomationRow(
                  game: widget.game,
                  id: row.id,
                  label: row.label,
                  note: row.note,
                  onOpen: () => setState(() => _open = row.id),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        if (open != null)
          Positioned.fill(
            child: HudModal(
              icon: Ic.automation,
              title: _rows
                  .firstWhere((row) => row.id == open)
                  .label
                  .toUpperCase(),
              anchor: ModalAnchor.centre,
              accent: Palette.gold,
              onClose: () => setState(() => _open = null),
              child: _settingsFor(open),
            ),
          ),
      ],
    );
  }
}

/// One automation as a row: a lamp for its state, the name, one line on
/// what it does, and at the far end either its price or the hint that a
/// tap opens its settings.
class _AutomationRow extends StatelessWidget {
  const _AutomationRow({
    required this.game,
    required this.id,
    required this.label,
    required this.note,
    required this.onOpen,
  });

  final Game game;
  final AutomationId id;
  final String label;
  final String note;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sim = game.sim;
    final owned = sim.automationUnlockedOf(id).value;
    final cost = Automations.costOf(id);
    final affordable = sim.canUnlockAutomation(id);
    final running = owned && _enabledOf(sim, id);
    final ink = owned
        ? (running ? Palette.tech : Palette.textDim)
        : Palette.gold;
    final plate = HudPlate(
      cut: 6,
      fill: owned
          ? Palette.well.withValues(alpha: 0.5)
          : const Color(0x00000000),
      edge: owned ? ink.withValues(alpha: 0.4) : Palette.lineBar,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: owned ? 1 : 0.55),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppText.body(
                    9.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: AppText.body(8, color: Palette.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (owned)
            Text(
              running ? 'працює ›' : 'вимкнено ›',
              style: AppText.display(8, color: Palette.textFaint),
            )
          else if (cost != null)
            HudButton(
              onTap: affordable
                  ? () {
                      if (sim.unlockAutomation(id)) game.pokeListeners();
                    }
                  : null,
              holdRepeat: true,
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'РОЗБЛОКУВАТИ · $cost',
                    style: AppText.display(
                      8.5,
                      weight: FontWeight.w700,
                      color: affordable ? Palette.gold : Palette.textFaint,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ResourceIcon(
                    ResourceId.credits,
                    size: 9,
                    colour: affordable ? null : Palette.textFaint,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    // Only an owned row is a door: a locked one has its button, and a
    // hand on the whole plate would announce a settings window that does
    // not exist yet.
    return owned ? HudTap(onTap: onOpen, cut: 6, child: plate) : plate;
  }

  static bool _enabledOf(PrototypeSimulation sim, AutomationId id) =>
      switch (id) {
        AutomationId.autoHands => sim.autoStrike.enabled.value,
        AutomationId.autoSell => sim.autoSeller.enabled.value,
        AutomationId.autoRequests => sim.autoFulfil.enabled.value,
        AutomationId.autoBuy => sim.autoBuyer.enabled.value,
        AutomationId.autoCraft => sim.autoCrafter.enabled.value,
      };
}

/// A small caption over a control, the settings' own eyebrow.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.display(6.5, letterSpacing: 0.6, color: Palette.textFaint),
    );
  }
}

/// The house switch with its word, wired to a signal and a repaint.
class _OnSwitch extends StatelessWidget {
  const _OnSwitch({
    required this.game,
    required this.enabled,
    this.energy = false,
  });

  final Game game;
  final Signal<bool> enabled;

  /// Whether flipping it moves the energy cadence.
  final bool energy;

  @override
  Widget build(BuildContext context) {
    return HudToggle(
      label: 'увімкнено',
      on: enabled.value,
      onTap: () {
        enabled.value = !enabled.value;
        if (energy) {
          game.refreshEnergyLoop();
        } else {
          game.pokeListeners();
        }
      },
    );
  }
}

/// A line of explanation under the controls: where the rest of the
/// settings live, or what the automation decides on its own.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.body(8, color: Palette.textFaint));
  }
}

class _StrikeSettings extends StatelessWidget {
  const _StrikeSettings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final auto = game.sim.autoStrike;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _OnSwitch(game: game, enabled: auto.enabled, energy: true),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'реген ',
                    style: AppText.display(7, color: Palette.textFaint),
                  ),
                  TextSpan(
                    text: '×${auto.regenSlowdown.value.toStringAsFixed(2)}',
                    style: AppText.display(
                      9.5,
                      weight: FontWeight.w700,
                      color: auto.enabled.value
                          ? Palette.amber
                          : Palette.textFaint,
                    ),
                  ),
                  TextSpan(
                    text: ' повільніше',
                    style: AppText.display(7, color: Palette.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _Caption('інтервал удару'),
        const SizedBox(height: 4),
        HudChoice<double>(
          options: [
            for (final seconds in AutoStrike.intervals)
              (seconds, intervalText(seconds)),
          ],
          value: auto.intervalSeconds.value,
          onPick: (seconds) {
            auto.intervalSeconds.value = seconds;
            game.refreshEnergyLoop();
          },
          stretch: true,
          cut: 5,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        ),
      ],
    );
  }
}

class _SellSettings extends StatelessWidget {
  const _SellSettings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final auto = game.sim.autoSeller;
    final live = auto.rules.values.where((rule) => rule.enabled.value).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _OnSwitch(game: game, enabled: auto.enabled),
            const Spacer(),
            Text(
              'позицій на авто: $live',
              style: AppText.body(9, color: Palette.textDim),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _Note(
          'які позиції продавати, інтервал і поріг «не нижче» — у картці '
          'позиції в Торгівлі',
        ),
      ],
    );
  }
}

class _RequestSettings extends StatelessWidget {
  const _RequestSettings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final auto = game.sim.autoFulfil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _OnSwitch(game: game, enabled: auto.enabled),
        const SizedBox(height: 9),
        const _Caption('запит бере не більше частки складу'),
        const SizedBox(height: 4),
        HudChoice<double>(
          options: [
            for (final share in AutoFulfil.shares)
              (share, '${(share * 100).round()}%'),
          ],
          value: auto.maxShare.value,
          onPick: (share) {
            auto.maxShare.value = share;
            game.pokeListeners();
          },
          stretch: true,
          cut: 5,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        ),
        const SizedBox(height: 9),
        const _Caption('не віддавати'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final row in PrototypeSimulation.priceTable)
              _ResourceChip(
                id: row.id,
                on: auto.isBlocked(row.id),
                onTap: () {
                  auto.setBlocked(row.id, !auto.isBlocked(row.id));
                  game.pokeListeners();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// A resource as a chip that toggles: amber-edged when it is picked.
class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.id,
    required this.on,
    required this.onTap,
  });

  final ResourceId id;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onTap,
      corners: HudCorners.centred,
      cut: 6,
      child: HudPlate(
        cut: 6,
        fill: on ? Palette.goldWell : Palette.shell,
        edge: on ? Palette.amber : Palette.lineBar,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: ResourceIcon(
              id,
              size: 15,
              colour: on
                  ? null
                  : resourceStyles[id]!.colour.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuySettings extends StatelessWidget {
  const _BuySettings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final auto = game.sim.autoBuyer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _OnSwitch(game: game, enabled: auto.enabled),
            const Spacer(),
            Text(
              'треків обрано: ${auto.chosen.value.length}',
              style: AppText.body(9, color: Palette.textDim),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _Caption('інтервал'),
        const SizedBox(height: 4),
        HudChoice<double>(
          options: [
            for (final seconds in automationIntervals)
              (seconds, intervalText(seconds)),
          ],
          value: auto.intervalSeconds.value,
          onPick: (seconds) {
            auto.intervalSeconds.value = seconds;
            game.pokeListeners();
          },
          stretch: true,
          cut: 5,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        ),
        const SizedBox(height: 9),
        const _Caption('покупок за цикл'),
        const SizedBox(height: 4),
        HudChoice<int>(
          options: [for (final n in AutoBuyer.perCycleOptions) (n, '$n')],
          value: auto.perCycle.value,
          onPick: (n) {
            auto.perCycle.value = n;
            game.pokeListeners();
          },
          stretch: true,
          cut: 5,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        ),
        const SizedBox(height: 9),
        const _Note(
          'що купувати — тумблер АВТО на рядках прокачки руки й бурів',
        ),
      ],
    );
  }
}

class _CraftSettings extends StatelessWidget {
  const _CraftSettings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final auto = game.sim.autoCrafter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _OnSwitch(game: game, enabled: auto.enabled),
            const Spacer(),
            Text(
              'ліній під планувальником: ${auto.managed.value.length}',
              style: AppText.body(9, color: Palette.textDim),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _Note(
          'вільна, голодна або виконана лінія бере рецепт із найбільшою '
          'ціною виходу за секунду, який склад може прогодувати',
        ),
      ],
    );
  }
}
