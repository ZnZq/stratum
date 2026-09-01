import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stratum_core/stratum_core.dart';

import '../game.dart';
import 'trade_group_card.dart';
import 'trade_request_card.dart';
import 'hud.dart';
import 'tokens.dart';

/// The two rooms of the trade post.
enum TradeMode { sell, requests }

/// Trade: where the shaft's haul becomes credits.
///
/// Prices are fixed by design, so nothing here is about timing -- the sell
/// room is a settings panel (what sells, what share of it) with one honest
/// button, and the requests room is the only place a premium exists.
class TradeScreen extends StatefulWidget {
  const TradeScreen({required this.game, super.key});

  final Game game;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  TradeMode _mode = TradeMode.sell;
  final Map<String, ResourceId> _picked = {};

  static const Map<String, String> _groupLabels = {
    'resources': 'РЕСУРСИ',
    'materials': 'МАТЕРІАЛИ',
    'building': 'БУДІВНИЦТВО',
    'tech': 'ТЕХНОЛОГІЇ',
  };

  /// A wall clock, not a ticker: request timers keep running through pause,
  /// exactly like the drift they share a nature with, so the countdowns must
  /// not freeze behind the pause glass.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    widget.game.sim.syncRequests(DateTime.now().millisecondsSinceEpoch);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      widget.game.sim.syncRequests(DateTime.now().millisecondsSinceEpoch);
      // Standing in the room reads the news as it arrives.
      if (_mode == TradeMode.requests) widget.game.markRequestsSeen();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.game.sim;
    return Padding(
      // 12 at the foot to match the sides: the mode strip's corner cuts
      // run parallel to the frame's, and an unequal inset read as the whole
      // strip sitting a shade too low.
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: switch (_mode) {
              TradeMode.sell => _sellRoom(sim),
              TradeMode.requests => _requestRoom(sim),
            },
          ),
          const SizedBox(height: 8),
          // Seated on the screen's floor: square on top, struck only at its
          // outer bottom corners, the two rooms sharing the width evenly.
          HudChoice<TradeMode>(
            options: const [
              (TradeMode.sell, 'ПРОДАЖ'),
              (TradeMode.requests, 'ЗАПИТИ'),
            ],
            value: _mode,
            // The same dot the navigation wears, on the exact cell it means:
            // the tab said "something in Торгівля", this says "in ЗАПИТИ".
            marked: {if (widget.game.hasUnseenRequests) TradeMode.requests},
            onPick: (mode) => setState(() {
              _mode = mode;
              if (mode == TradeMode.requests) {
                widget.game.markRequestsSeen();
              }
            }),
            stretch: true,
            top: false,
            cut: 9,
            size: 9.5,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ sell

  Widget _sellRoom(PrototypeSimulation sim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: HudStat(
                label: 'кредити',
                corners: const HudCorners(topLeft: true),
                value: '${sim.stock.amount(ResourceId.credits)}',
                size: 17,
                accent: Palette.gold,
                colour: Palette.gold,
                labelColour: Palette.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudStat(
                label: 'за налаштуваннями',
                align: CrossAxisAlignment.end,
                corners: const HudCorners(topRight: true),
                value: '+${sim.sellAllYield()}',
                size: 17,
                accent: Palette.tech,
                colour: Palette.tech,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in PrototypeSimulation.tradeGroups) ...[
                  if (group.key != PrototypeSimulation.tradeGroups.first.key)
                    const SizedBox(height: 10),
                  GroupCard(
                    sim: sim,
                    label: _groupLabels[group.key]!,
                    members: group.ids,
                    group: sim.sellingGroupOf(group.key),
                    picked: _picked[group.key] ?? group.ids.first,
                    onPick: (id) => setState(() => _picked[group.key] = id),
                    onChange: _poke,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        HudButton(
          onTap: sim.sellAllYield().isZero ? null : () => _poke(sim.sellAll),
          label: 'ПРОДАТИ ВСЕ · +${sim.sellAllYield()}',
          padding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ],
    );
  }

  void _poke(VoidCallback act) {
    act();
    setState(() {});
    // The financing strip lives outside this screen and normally hears
    // about money on the next engine batch -- a second late, which unhooks
    // the chase animation from the tap that caused it.
    widget.game.pokeListeners();
  }

  // -------------------------------------------------------------- requests

  Widget _requestRoom(PrototypeSimulation sim) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = sim.nextRequestAtMs - now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: HudStat(
                label: 'слоти',
                corners: const HudCorners(topLeft: true),
                value: '${sim.requests.length} / ${sim.requestSlots}',
                size: 17,
                accent: Palette.tech,
                colour: Palette.tech,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HudStat(
                label: 'новий через',
                align: CrossAxisAlignment.end,
                corners: const HudCorners(topRight: true),
                value: _clockText(until),
                size: 17,
                accent: Palette.steel,
                colour: Palette.steel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final request in sim.requests) ...[
                  RequestCard(sim: sim, request: request, onChange: _poke),
                  const SizedBox(height: 10),
                ],
                if (sim.requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'дошка порожня · новий запит уже в дорозі',
                        style: AppText.body(11, color: Palette.textFaint),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _clockText(int ms) {
    if (ms <= 0) return '0:00';
    final seconds = (ms / 1000).ceil();
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}
