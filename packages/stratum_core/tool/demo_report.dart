import 'dart:io';

import 'package:stratum_core/stratum_core.dart';

/// Produces a sample balance report so the viewer can be judged before the real
/// simulation exists. The curves are a placeholder shaped like an idle economy:
/// linear income against an exponential price ladder.
void main(List<String> args) {
  var drills = 0;
  var ore = BigDouble.zero;
  var depth = 0.0;
  var restarts = 0;
  final rng = RandomSource(seed: 20260825);
  final crit = rng.stream('crit');

  final harness = BalanceHarness(
    rate: TickRate(const Duration(seconds: 4)),
    sampleEvery: 20,
    probes: [
      BalanceProbe('depth', () => depth),
      BalanceProbe('drills', () => drills.toDouble()),
      BalanceProbe.magnitude('ore', () => ore),
      BalanceProbe.magnitude('next drill price', () => _price(drills)),
      BalanceProbe('restarts', () => restarts.toDouble()),
    ],
  );

  final report = harness.run(
    ticks: 9000,
    onTick: (tick) {
      final power = (10 + 6 * drills) * (crit.chance(0.05) ? 2.0 : 1.0);
      ore += BigDouble.fromNum(power);
      depth += power / (5 * _densityAt(depth));

      final affordable = BigDouble.affordGeometricSeries(
        ore,
        15.big,
        1.13.big,
        drills.big,
      );
      if (affordable > BigDouble.zero) {
        final count = affordable.toDouble().floor();
        ore -= BigDouble.sumGeometricSeries(
          count.big,
          15.big,
          1.13.big,
          drills.big,
        );
        drills += count;
      }

      if (depth > 400 * (restarts + 1)) {
        restarts++;
        drills = 0;
        ore = BigDouble.zero;
        depth = 0;
      }
    },
  );

  final html = report.toHtml(
    title: 'STRATUM - placeholder progression',
    charts: [
      BalanceChart(title: 'depth over time', probes: ['depth']),
      BalanceChart(title: 'restarts over time', probes: ['restarts']),
      BalanceChart(
        title: 'ore against the next drill price (orders of magnitude)',
        probes: ['ore', 'next drill price'],
      ),
      BalanceChart(title: 'drills owned', probes: ['drills']),
    ],
  );

  final target = args.isEmpty ? 'balance_report.html' : args.first;
  File(target).writeAsStringSync(html);
  File('$target.csv').writeAsStringSync(report.toCsv());

  stdout.writeln('wrote $target (${html.length} bytes)');
  stdout.writeln('restarts: $restarts');
  stdout.writeln('first restart at: ${report.timeToReach('restarts', 1)}');
}

BigDouble _price(int owned) => 15.big * 1.13.big.pow(owned.toDouble());

double _densityAt(double depth) => 1.055 * (1 + depth / 50);
