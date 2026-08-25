import 'dart:math' as math;

import 'big_double.dart';
import 'tick_scheduler.dart';

/// A named measurement taken from the simulation while it runs.
class BalanceProbe {
  const BalanceProbe(this.name, this.read);

  /// Records the order of magnitude instead of the value.
  ///
  /// Charts in this genre are log scale by necessity: past 1e308 a plain double
  /// is infinity, and a linear axis says nothing about a curve that climbs
  /// through hundreds of orders anyway. Zero maps to the floor rather than to
  /// negative infinity.
  factory BalanceProbe.magnitude(String name, BigDouble Function() read) =>
      BalanceProbe(name, () {
        final value = read();
        return value.sign <= 0 ? 0 : value.log10();
      });

  final String name;
  final double Function() read;
}

class BalanceSample {
  const BalanceSample({
    required this.tick,
    required this.elapsed,
    required this.values,
  });

  final int tick;

  /// Game time, derived from the tick rate rather than measured.
  final Duration elapsed;

  final Map<String, double> values;
}

/// One chart in the report; several probes on one chart share an axis.
///
/// Overlaying is the technique that finds walls: the point where a cost curve
/// crosses an income curve is invisible on either curve alone.
class BalanceChart {
  const BalanceChart({required this.title, required this.probes});

  final String title;
  final List<String> probes;
}

/// Runs a simulation for a fixed number of ticks and records the probes.
class BalanceHarness {
  BalanceHarness({
    required this.rate,
    required this.probes,
    this.sampleEvery = 1,
  }) {
    if (sampleEvery < 1) {
      throw ArgumentError.value(
        sampleEvery,
        'sampleEvery',
        'the sampling interval must be positive',
      );
    }
    final names = <String>{};
    for (final probe in probes) {
      if (!names.add(probe.name)) {
        throw ArgumentError.value(probe.name, 'probes', 'duplicate probe name');
      }
    }
  }

  final TickRate rate;
  final List<BalanceProbe> probes;

  /// How many ticks pass between samples. The first and the last tick are
  /// always recorded, whatever the interval.
  final int sampleEvery;

  BalanceReport run({
    required int ticks,
    required void Function(int tick) onTick,
  }) {
    if (ticks < 1) {
      throw ArgumentError.value(ticks, 'ticks', 'a run needs at least one tick');
    }

    final samples = <BalanceSample>[_sampleAt(0)];
    for (var tick = 0; tick < ticks; tick++) {
      onTick(tick);
      final completed = tick + 1;
      if (completed % sampleEvery == 0 || completed == ticks) {
        samples.add(_sampleAt(completed));
      }
    }

    return BalanceReport(
      rate: rate,
      probeNames: [for (final probe in probes) probe.name],
      samples: samples,
    );
  }

  BalanceSample _sampleAt(int tick) => BalanceSample(
        tick: tick,
        elapsed: _elapsedAt(tick),
        values: {for (final probe in probes) probe.name: probe.read()},
      );

  Duration _elapsedAt(int tick) => Duration(
        microseconds:
            rate.interval.inMicroseconds * tick ~/ rate.ticksPerFire,
      );
}

/// What a run produced, plus the questions worth asking of it.
class BalanceReport {
  const BalanceReport({
    required this.rate,
    required this.probeNames,
    required this.samples,
  });

  final TickRate rate;
  final List<String> probeNames;
  final List<BalanceSample> samples;

  /// The first sample where [probe] reached [threshold], or null if it never
  /// did within the run.
  BalanceSample? firstSampleAtOrAbove(String probe, double threshold) {
    _requireProbe(probe);
    for (final sample in samples) {
      final value = sample.values[probe];
      if (value != null && value >= threshold) return sample;
    }
    return null;
  }

  Duration? timeToReach(String probe, double threshold) =>
      firstSampleAtOrAbove(probe, threshold)?.elapsed;

  /// The change in [probe] between consecutive samples.
  ///
  /// A stall is nearly invisible on a cumulative curve and unmistakable on its
  /// derivative, so this is where a wall shows itself.
  List<double> changePerSample(String probe) {
    _requireProbe(probe);
    return [
      for (var i = 1; i < samples.length; i++)
        (samples[i].values[probe] ?? 0) - (samples[i - 1].values[probe] ?? 0),
    ];
  }

  String toCsv() {
    final buffer = StringBuffer('tick,seconds,${probeNames.join(',')}\n');
    for (final sample in samples) {
      buffer.write(sample.tick);
      buffer.write(',');
      buffer.write(sample.elapsed.inSeconds);
      for (final name in probeNames) {
        buffer.write(',');
        buffer.write(sample.values[name] ?? '');
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// A self-contained page: inline SVG, no scripts, no network.
  ///
  /// It has to open straight from a local file with no server and no
  /// connection, which rules out every charting library.
  String toHtml({required String title, List<BalanceChart>? charts}) {
    final resolved = charts ??
        [for (final name in probeNames) BalanceChart(title: name, probes: [name])];
    for (final chart in resolved) {
      for (final probe in chart.probes) {
        _requireProbe(probe);
      }
    }

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en"><head><meta charset="utf-8">')
      ..writeln('<title>${_escape(title)}</title>')
      ..writeln('<style>$_style</style>')
      ..writeln('</head><body>')
      ..writeln('<h1>${_escape(title)}</h1>')
      ..writeln('<p class="meta">${samples.length} samples over '
          '${samples.last.tick} ticks '
          '(${_formatDuration(samples.last.elapsed)} of game time) at '
          '${_escape(rate.toString())}</p>');

    for (final chart in resolved) {
      buffer.writeln(_renderChart(chart));
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String _renderChart(BalanceChart chart) {
    const width = 900.0;
    const height = 280.0;
    const padding = 44.0;

    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final probe in chart.probes) {
      for (final sample in samples) {
        final value = sample.values[probe];
        if (value == null || !value.isFinite) continue;
        minY = math.min(minY, value);
        maxY = math.max(maxY, value);
      }
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 1;
    }
    // A flat series would otherwise divide by a zero span and render as NaN.
    if (maxY - minY < 1e-12) {
      maxY = minY + 1;
    }

    final lastTick = samples.last.tick;
    final xSpan = lastTick == 0 ? 1 : lastTick;

    double x(int tick) =>
        padding + (width - padding * 2) * (tick / xSpan);
    double y(double value) =>
        height - padding - (height - padding * 2) * ((value - minY) / (maxY - minY));

    final buffer = StringBuffer()
      ..writeln('<section>')
      ..writeln('<h2>${_escape(chart.title)}</h2>')
      ..writeln('<svg viewBox="0 0 $width $height" role="img">')
      ..writeln('<rect class="plot" x="$padding" y="$padding" '
          'width="${width - padding * 2}" height="${height - padding * 2}"/>');

    for (var i = 0; i < chart.probes.length; i++) {
      final probe = chart.probes[i];
      final points = [
        for (final sample in samples)
          if (sample.values[probe] case final value?
              when value.isFinite)
            '${x(sample.tick).toStringAsFixed(2)},'
                '${y(value).toStringAsFixed(2)}',
      ].join(' ');
      buffer.writeln('<polyline class="s${i % _seriesColours}" points="$points"/>');
    }

    buffer
      ..writeln('<text class="axis" x="$padding" y="${padding - 12}">'
          '${_escape(_formatValue(maxY))}</text>')
      ..writeln('<text class="axis" x="$padding" y="${height - padding + 18}">'
          '${_escape(_formatValue(minY))}</text>')
      ..writeln('<text class="axis end" x="${width - padding}" '
          'y="${height - padding + 18}">'
          '${_formatDuration(samples.last.elapsed)}</text>')
      ..writeln('</svg>')
      ..writeln('<p class="legend">');

    for (var i = 0; i < chart.probes.length; i++) {
      buffer.writeln('<span class="key s${i % _seriesColours}">'
          '${_escape(chart.probes[i])}</span>');
    }

    buffer
      ..writeln('</p>')
      ..writeln('</section>');
    return buffer.toString();
  }

  void _requireProbe(String probe) {
    if (!probeNames.contains(probe)) {
      throw ArgumentError.value(probe, 'probe', 'no such probe in this report');
    }
  }

  static const int _seriesColours = 5;

  static String _formatValue(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d ${duration.inHours % 24}h';
    if (duration.inHours > 0) return '${duration.inHours}h ${duration.inMinutes % 60}m';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    return '${duration.inSeconds}s';
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const String _style = '''
body{background:#0f1115;color:#e8e9ee;font:14px/1.5 system-ui,sans-serif;margin:0;padding:28px}
h1{font-size:20px;font-weight:600;margin:0 0 4px}
h2{font-size:14px;font-weight:600;margin:0 0 8px;color:#c9ccd6}
.meta{color:#8b8fa0;margin:0 0 28px}
section{background:#161922;border:1px solid #232734;border-radius:10px;padding:16px;margin-bottom:20px}
svg{width:100%;height:auto;display:block}
rect.plot{fill:#0f1115;stroke:#232734}
polyline{fill:none;stroke-width:2;vector-effect:non-scaling-stroke}
text.axis{fill:#8b8fa0;font-size:11px}
text.end{text-anchor:end}
.legend{margin:10px 0 0;display:flex;gap:14px;flex-wrap:wrap}
.key{font-size:12px;display:flex;align-items:center;gap:6px}
.key::before{content:"";width:14px;height:2px;background:currentColor}
.s0{stroke:#ffd782;color:#ffd782}
.s1{stroke:#7f77dd;color:#7f77dd}
.s2{stroke:#9fe1cb;color:#9fe1cb}
.s3{stroke:#ed93b1;color:#ed93b1}
.s4{stroke:#85b7eb;color:#85b7eb}
''';
}
