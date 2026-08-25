import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// A stand-in for the game: one counter that grows every tick.
class Counter {
  int ticks = 0;
  double value = 0;

  void tick() {
    ticks++;
    value += ticks.toDouble();
  }
}

void main() {
  group('running', () {
    test('ticks exactly as many times as asked', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('value', () => counter.value)],
      );

      harness.run(ticks: 100, onTick: (_) => counter.tick());

      expect(counter.ticks, 100);
    });

    test('samples every tick by default, plus the starting state', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('value', () => counter.value)],
      );

      final report = harness.run(ticks: 10, onTick: (_) => counter.tick());

      expect(report.samples, hasLength(11));
      expect(report.samples.first.tick, 0);
      expect(report.samples.last.tick, 10);
    });

    test('honours a wider sampling interval', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('value', () => counter.value)],
        sampleEvery: 25,
      );

      final report = harness.run(ticks: 100, onTick: (_) => counter.tick());

      expect(report.samples.map((s) => s.tick), [0, 25, 50, 75, 100]);
    });

    test('always samples the final tick, even off the interval', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('value', () => counter.value)],
        sampleEvery: 30,
      );

      final report = harness.run(ticks: 100, onTick: (_) => counter.tick());

      expect(report.samples.last.tick, 100);
    });

    test('turns tick counts into game time through the rate', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('value', () => counter.value)],
        sampleEvery: 15,
      );

      final report = harness.run(ticks: 30, onTick: (_) => counter.tick());

      expect(report.samples[1].elapsed, const Duration(minutes: 1));
      expect(report.samples[2].elapsed, const Duration(minutes: 2));
    });

    test('accounts for several ticks per fire', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 1), ticksPerFire: 2),
        probes: [BalanceProbe('value', () => counter.value)],
        sampleEvery: 10,
      );

      final report = harness.run(ticks: 10, onTick: (_) => counter.tick());

      expect(report.samples.last.elapsed, const Duration(seconds: 5));
    });

    test('reads every probe at every sample', () {
      final counter = Counter();
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [
          BalanceProbe('value', () => counter.value),
          BalanceProbe('ticks', () => counter.ticks.toDouble()),
        ],
        sampleEvery: 5,
      );

      final report = harness.run(ticks: 10, onTick: (_) => counter.tick());

      expect(report.samples[1].values['ticks'], 5);
      expect(report.samples[1].values['value'], 15);
    });

    test('passes the tick index to the callback', () {
      final seen = <int>[];
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: const [],
      );

      harness.run(ticks: 3, onTick: seen.add);

      expect(seen, [0, 1, 2]);
    });

    test('rejects a run with no ticks', () {
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: const [],
      );

      expect(() => harness.run(ticks: 0, onTick: (_) {}), throwsArgumentError);
    });

    test('rejects a non-positive sampling interval', () {
      expect(
        () => BalanceHarness(
          rate: TickRate(const Duration(seconds: 4)),
          probes: const [],
          sampleEvery: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects two probes sharing a name', () {
      expect(
        () => BalanceHarness(
          rate: TickRate(const Duration(seconds: 4)),
          probes: [
            BalanceProbe('same', () => 1),
            BalanceProbe('same', () => 2),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('magnitude probes', () {
    test('record the order of magnitude of a BigDouble', () {
      // Charts in this genre are log scale by necessity: past 1e308 a plain
      // double is infinity, and a linear axis says nothing anyway.
      var ore = BigDouble(1, 500);
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe.magnitude('ore', () => ore)],
      );

      final report = harness.run(ticks: 1, onTick: (_) => ore = BigDouble(1, 600));

      expect(report.samples.first.values['ore'], closeTo(500, 1e-9));
      expect(report.samples.last.values['ore'], closeTo(600, 1e-9));
    });

    test('map zero to a floor instead of negative infinity', () {
      final harness = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe.magnitude('ore', () => BigDouble.zero)],
      );

      final report = harness.run(ticks: 1, onTick: (_) {});

      expect(report.samples.first.values['ore'], 0);
    });
  });

  group('finding the shape of a run', () {
    BalanceReport reportOf(double Function(int tick) shape, {int ticks = 100}) {
      var current = 0.0;
      return BalanceHarness(
        rate: TickRate(const Duration(seconds: 1)),
        probes: [BalanceProbe('v', () => current)],
      ).run(ticks: ticks, onTick: (tick) => current = shape(tick));
    }

    test('reports when a probe first crosses a threshold', () {
      final report = reportOf((tick) => tick.toDouble());

      expect(report.firstSampleAtOrAbove('v', 42)?.tick, 43);
    });

    test('reports the game time it took to get there', () {
      final report = reportOf((tick) => tick.toDouble());

      expect(report.timeToReach('v', 42), const Duration(seconds: 43));
    });

    test('reports null when the threshold is never reached', () {
      final report = reportOf((tick) => tick.toDouble());

      expect(report.firstSampleAtOrAbove('v', 1e9), isNull);
      expect(report.timeToReach('v', 1e9), isNull);
    });

    test('exposes the per-sample change, where walls actually show up', () {
      // A stall is nearly invisible on a cumulative curve and obvious on its
      // derivative, so the report hands the derivative over directly.
      final report = reportOf(
        (tick) => tick < 50 ? tick.toDouble() : 50 + (tick - 50) * 0.1,
        ticks: 100,
      );
      final deltas = report.changePerSample('v');

      expect(deltas[10], closeTo(1, 1e-9));
      expect(deltas[80], closeTo(0.1, 1e-9));
    });

    test('rejects a probe it never recorded', () {
      final report = reportOf((tick) => tick.toDouble());

      expect(() => report.changePerSample('nope'), throwsArgumentError);
      expect(() => report.timeToReach('nope', 1), throwsArgumentError);
    });
  });

  group('csv', () {
    test('starts with a header naming tick, time and every probe', () {
      final counter = Counter();
      final report = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [
          BalanceProbe('value', () => counter.value),
          BalanceProbe('ticks', () => counter.ticks.toDouble()),
        ],
        sampleEvery: 5,
      ).run(ticks: 10, onTick: (_) => counter.tick());

      final lines = report.toCsv().trim().split('\n');

      expect(lines.first, 'tick,seconds,value,ticks');
      expect(lines, hasLength(4));
    });

    test('writes one row per sample', () {
      final counter = Counter();
      final report = BalanceHarness(
        rate: TickRate(const Duration(seconds: 2)),
        probes: [BalanceProbe('value', () => counter.value)],
        sampleEvery: 10,
      ).run(ticks: 10, onTick: (_) => counter.tick());

      final lines = report.toCsv().trim().split('\n');

      expect(lines[1], startsWith('0,0,'));
      expect(lines[2], startsWith('10,20,'));
    });
  });

  group('html report', () {
    BalanceReport sampleReport() {
      var value = 0.0;
      var cost = 1.0;
      return BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [
          BalanceProbe('income', () => value),
          BalanceProbe('cost', () => cost),
        ],
        sampleEvery: 10,
      ).run(ticks: 100, onTick: (tick) {
        value += 1;
        cost *= 1.05;
      });
    }

    test('is a complete document', () {
      final html = sampleReport().toHtml(title: 'run');

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html.trimRight(), endsWith('</html>'));
    });

    test('pulls nothing from the network', () {
      // It has to open from a local file with no server and no connection.
      final html = sampleReport().toHtml(title: 'run');

      expect(html, isNot(contains('http://')));
      expect(html, isNot(contains('https://')));
      expect(html, isNot(contains('<script src')));
    });

    test('draws a line per series', () {
      final html = sampleReport().toHtml(title: 'run');

      expect('<polyline'.allMatches(html).length, 2);
    });

    test('names every probe', () {
      final html = sampleReport().toHtml(title: 'run');

      expect(html, contains('income'));
      expect(html, contains('cost'));
    });

    test('can overlay several probes on one chart', () {
      // The technique that finds walls: the point where cost crosses income is
      // invisible on either curve alone.
      final html = sampleReport().toHtml(
        title: 'run',
        charts: [
          BalanceChart(title: 'cost against income', probes: ['income', 'cost']),
        ],
      );

      expect('<svg'.allMatches(html).length, 1);
      expect('<polyline'.allMatches(html).length, 2);
    });

    test('escapes text that would otherwise break the markup', () {
      final html = sampleReport().toHtml(title: '<script>bad</script>');

      expect(html, isNot(contains('<script>bad')));
      expect(html, contains('&lt;script&gt;'));
    });

    test('survives a run with a single sample', () {
      var value = 0.0;
      final report = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('v', () => value)],
        sampleEvery: 1000,
      ).run(ticks: 1, onTick: (_) => value = 5);

      expect(() => report.toHtml(title: 'tiny'), returnsNormally);
    });

    test('survives a probe that never moves', () {
      final report = BalanceHarness(
        rate: TickRate(const Duration(seconds: 4)),
        probes: [BalanceProbe('flat', () => 7)],
        sampleEvery: 5,
      ).run(ticks: 20, onTick: (_) {});

      final html = report.toHtml(title: 'flat');

      expect(html, contains('<polyline'));
      expect(html, isNot(contains('NaN')));
    });

    test('rejects a chart naming a probe that was never recorded', () {
      expect(
        () => sampleReport().toHtml(
          title: 'run',
          charts: [BalanceChart(title: 'bad', probes: ['nope'])],
        ),
        throwsArgumentError,
      );
    });
  });
}
