import 'package:flutter/widgets.dart';

import '../save_slot.dart';
import '../save_summary.dart';

import '../game.dart';
import 'save_slot_card.dart';
import 'hud.dart';
import 'game_icons.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

/// The save slots: what is in each, and the three things one can do with it.
///
/// The autosave is listed alongside the manual slots rather than hidden, so
/// the player can see the thing that is actually protecting their run, and
/// load it back after a mistake.
///
/// Every action here destroys something -- a save, or the run in progress --
/// and none of them can be undone, so each is armed by its own tick first. The
/// tick clears itself after the action, so a card is never left loaded.
class SaveMenu extends StatefulWidget {
  const SaveMenu({
    required this.game,
    required this.onClose,
    required this.floor,
    super.key,
  });

  final Game game;
  final VoidCallback onClose;

  /// What the navigation takes under the sheet; see [HudModal.floor].
  final double floor;

  @override
  State<SaveMenu> createState() => _SaveMenuState();
}

class _SaveMenuState extends State<SaveMenu> {
  List<SaveSummary>? _slots;
  SaveSlot? _expanded;
  final Set<SaveSlot> _armed = {};
  String? _said;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final slots = await widget.game.store.list();
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _run(
    SaveSlot slot,
    String said,
    Future<bool> Function() action,
  ) async {
    final done = await action();
    if (!mounted) return;
    setState(() {
      _said = done ? said : 'не вдалося: сховище недоступне';
      _failed = !done;
      _armed.remove(slot);
    });
    await _refresh();
  }

  SaveSummary? _summaryOf(SaveSlot slot) {
    for (final summary in _slots ?? const <SaveSummary>[]) {
      if (summary.slot == slot) return summary;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return HudModal(
      icon: Ic.saves,
      title: 'ЗБЕРЕЖЕННЯ',
      anchor: ModalAnchor.stretch,
      floor: widget.floor,
      contentPadding: EdgeInsets.zero,
      onClose: widget.onClose,
      footer: _Footer(
        said: _said,
        failed: _failed,
        fault: widget.game.storageFault,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          for (final slot in SaveSlot.values)
            SlotCard(
              slot: slot,
              summary: _summaryOf(slot),
              loading: _slots == null,
              expanded: _expanded == slot,
              armed: _armed.contains(slot),
              onToggle: () =>
                  setState(() => _expanded = _expanded == slot ? null : slot),
              onArm: () => setState(() {
                if (!_armed.remove(slot)) _armed.add(slot);
              }),
              onSave: () => _run(
                slot,
                'записано в «${slot.label}»',
                () => widget.game.saveTo(slot),
              ),
              onLoad: () => _run(
                slot,
                'завантажено «${slot.label}»',
                () => widget.game.loadFrom(slot),
              ),
              onDelete: slot == SaveSlot.auto
                  ? null
                  : () => _run(
                      slot,
                      '«${slot.label}» стерто',
                      () => widget.game.deleteSlot(slot),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.said,
    required this.failed,
    required this.fault,
  });

  /// What the last action did. Shown here rather than as a toast: the menu is
  /// where the action happened, so the confirmation belongs in it.
  final String? said;
  final bool failed;

  /// What the store last failed with, if it is failing at all.
  final String? fault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.lineBar)),
      ),
      child: Row(
        children: [
          Icon(
            failed
                ? Ti.alertTriangle
                : said == null
                ? Ti.clock
                : Ti.check,
            size: 12,
            color: failed
                ? Palette.quantonium
                : said == null
                ? Palette.textFaint
                : Palette.tech,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              failed && fault != null
                  ? '$said · $fault'
                  : said ??
                        'автозбереження: кожні '
                            '${Game.autosaveEvery.inMinutes} хв, при втраті '
                            'фокуса і перед закриттям',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                9.5,
                color: failed
                    ? Palette.quantonium
                    : said == null
                    ? Palette.textFaint
                    : Palette.tech,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
