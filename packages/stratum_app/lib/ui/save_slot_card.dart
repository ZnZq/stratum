import 'package:flutter/widgets.dart';

import '../save_slot.dart';
import '../save_summary.dart';

import 'package:stratum_core/stratum_core.dart';

import 'hud.dart';
import 'resource_style.dart';
import 'tabler_icons.dart';
import 'tokens.dart';

class SlotCard extends StatelessWidget {
  const SlotCard({
    required this.slot,
    required this.summary,
    required this.loading,
    required this.expanded,
    required this.armed,
    required this.onToggle,
    required this.onArm,
    required this.onSave,
    required this.onLoad,
    required this.onDelete,
    super.key,
  });

  final SaveSlot slot;
  final SaveSummary? summary;
  final bool loading;
  final bool expanded;
  final bool armed;
  final VoidCallback onToggle;
  final VoidCallback onArm;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback? onDelete;

  static String when(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }

  static String played(Duration span) {
    if (span.inHours > 0) {
      return '${span.inHours} год ${span.inMinutes % 60} хв';
    }
    if (span.inMinutes > 0) return '${span.inMinutes} хв';
    return '${span.inSeconds} с';
  }

  @override
  Widget build(BuildContext context) {
    final held = summary;
    final isAuto = slot == SaveSlot.auto;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Palette.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: armed
              ? Palette.amber
              : isAuto
              ? const Color(0x337FD9C4)
              : Palette.lineBar,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HudTap(
            onTap: held == null ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAuto ? Ti.refresh : Ti.deviceFloppy,
                        size: 14,
                        color: held == null ? Palette.textFaint : Palette.tech,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        slot.label,
                        style: AppText.body(
                          12,
                          weight: FontWeight.w700,
                          color: Palette.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        loading
                            ? '…'
                            : held == null
                            ? 'порожньо'
                            : when(held.savedAt),
                        style: AppText.display(10.5, color: Palette.textMuted),
                      ),
                      if (held != null) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: const Icon(
                            Ti.chevronDown,
                            size: 13,
                            color: Palette.textFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (held != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(text: '${held.depth} м', colour: Palette.gold),
                        const SizedBox(width: 6),
                        _Chip(
                          text: '${held.drills} × бур',
                          colour: Palette.tech,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          text: played(held.playtime),
                          colour: Palette.textMuted,
                        ),
                      ],
                    ),
                    if (held.fromBackup)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'прочитано з резервної копії',
                          style: AppText.body(9.5, color: Palette.amber),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded && held != null) _Detail(summary: held),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Confirm(
                  armed: armed,
                  onTap: onArm,
                  label: held == null
                      ? 'підтверджую запис у цей слот'
                      : 'підтверджую: це перезапише або замінить прогрес',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Action(
                      label: 'записати',
                      icon: Ti.deviceFloppy,
                      onTap: armed ? onSave : null,
                      accent: Palette.tech,
                    ),
                    const SizedBox(width: 7),
                    _Action(
                      label: 'завантажити',
                      icon: Ti.refresh,
                      onTap: armed && held != null ? onLoad : null,
                      accent: Palette.gold,
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 7),
                      _Action(
                        label: 'стерти',
                        icon: Ti.trash,
                        onTap: armed && held != null ? onDelete : null,
                        accent: Palette.quantonium,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What is actually inside the save, for deciding whether to load it.
class _Detail extends StatelessWidget {
  const _Detail({required this.summary});

  final SaveSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Palette.bar,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.lineBar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Fact(label: 'глибина', value: '${summary.depth} м'),
              _Fact(label: 'бурів', value: '${summary.drills}'),
              _Fact(label: 'рівень бура', value: '${summary.drillPower}'),
              _Fact(label: 'перезапусків', value: '${summary.restarts}'),
            ],
          ),
          const SizedBox(height: 9),
          const HudRule(),
          const SizedBox(height: 8),
          for (final id in ResourceId.values)
            if (!summary.amount(id).isZero)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      resourceStyles[id]!.icon,
                      size: 13,
                      color: resourceStyles[id]!.colour,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        resourceStyles[id]!.label,
                        style: AppText.body(10.5, color: Palette.textMuted),
                      ),
                    ),
                    Text(
                      '${summary.amount(id)}',
                      style: AppText.display(
                        11.5,
                        weight: FontWeight.w700,
                        color: resourceStyles[id]!.colour,
                      ),
                    ),
                  ],
                ),
              ),
          if (ResourceId.values.every((id) => summary.amount(id).isZero))
            Text(
              'склад порожній',
              style: AppText.body(10, color: Palette.textFaint),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              7.5,
              weight: FontWeight.w700,
              color: Palette.tech,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: AppText.display(
              12.5,
              weight: FontWeight.w700,
              color: Palette.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.bar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppText.display(10, weight: FontWeight.w600, color: colour),
      ),
    );
  }
}

/// The tick that arms a card.
class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.armed,
    required this.onTap,
    required this.label,
  });

  final bool armed;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return HudTap(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: armed ? Palette.boostWell : Palette.bar,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: armed ? Palette.amber : Palette.line),
            ),
            child: armed
                ? const Icon(Ti.check, size: 11, color: Palette.amber)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppText.body(
                9.5,
                weight: armed ? FontWeight.w700 : FontWeight.w500,
                color: armed ? Palette.amber : Palette.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    return Expanded(
      child: HudTap(
        onTap: onTap,
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: live ? Palette.card : Palette.bar,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: live ? Palette.line : Palette.lineBar),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: live ? accent : Palette.textFaint),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.body(
                  10.5,
                  weight: FontWeight.w700,
                  color: live ? Palette.textDim : Palette.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
