import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'frame_clock.dart';
import 'tokens.dart';

/// The AI as it stands: a sphere with a core, and rays from the core to
/// the shell. Drawn as depth, not as a picture -- the ray ends sit on an
/// actual sphere that turns on two axes and is projected with a little
/// perspective, back rays first and dimmer, front rays last and bright,
/// so the eye reads a volume out of a few hundred canvas operations.
///
/// Built to hold its frame rate: the lattices are computed once and kept
/// in flat float arrays, the frame does no allocation beyond the point
/// batches it hands the canvas, every dot is a batched raw point, no
/// gradient is compiled per ray, the gradients that do exist are made
/// once in unit space and scaled by the canvas, and the whole scene is
/// its own repaint boundary so its ticker never redraws the shell.
///
/// [rays] is how many rays the core throws, [pressure] how tightly the
/// core sits in its shell (the model against its server), and [colours]
/// what the rays are tinted with, dealt out deterministically.
class AiSphere extends StatefulWidget {
  const AiSphere({
    required this.rays,
    required this.pressure,
    required this.colours,
    this.size = 260,
    super.key,
  });

  final int rays;
  final double pressure;
  final List<Color> colours;
  final double size;

  @override
  State<AiSphere> createState() => _AiSphereState();
}

class _AiSphereState extends State<AiSphere>
    with SingleTickerProviderStateMixin, FrameClock {
  final ValueNotifier<double> _time = ValueNotifier(0);
  late _SphereScene _scene = _SphereScene(widget.rays, widget.colours);

  @override
  void onFrame(double dt, Duration raw) => _time.value += dt;

  @override
  void didUpdateWidget(AiSphere old) {
    super.didUpdateWidget(old);
    if (old.rays != widget.rays || old.colours != widget.colours) {
      _scene = _SphereScene(widget.rays, widget.colours);
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _SpherePainter(
            time: _time,
            scene: _scene,
            pressure: widget.pressure,
          ),
        ),
      ),
    );
  }
}

/// A lattice of unit-sphere points in flat arrays, plus the scratch the
/// frame projects them into. One per ray count; nothing here is rebuilt
/// while the sphere turns.
class _Lattice {
  _Lattice(int count)
    : n = count,
      x = Float64List(count),
      y = Float64List(count),
      z = Float64List(count),
      px = Float64List(count),
      py = Float64List(count),
      depth = Float64List(count),
      scale = Float64List(count),
      order = List<int>.generate(count, (i) => i) {
    // A Fibonacci lattice: even over the sphere, and stable as the count
    // grows -- a new point is one more point, the rest stay put.
    const golden = 2.399963229728653;
    for (var i = 0; i < count; i++) {
      final v = 1 - (i + 0.5) * 2 / count;
      final r = math.sqrt(1 - v * v);
      final theta = golden * i;
      x[i] = math.cos(theta) * r;
      y[i] = v;
      z[i] = math.sin(theta) * r;
    }
  }

  final int n;
  final Float64List x, y, z;

  /// Projected screen position, depth (-1 back .. +1 front) and the
  /// perspective scale that depth earned; refilled every frame.
  final Float64List px, py, depth, scale;

  /// Indices sorted back to front, resorted every frame.
  final List<int> order;

  /// How much the far side shrinks: the lens, not a real camera.
  static const double _lens = 0.32;

  void project(double a, double b, Offset centre, double radius) {
    final ca = math.cos(a), sa = math.sin(a);
    final cb = math.cos(b), sb = math.sin(b);
    for (var i = 0; i < n; i++) {
      // Spin about Y, then tilt about X.
      final x1 = x[i] * ca + z[i] * sa;
      final z1 = -x[i] * sa + z[i] * ca;
      final y2 = y[i] * cb - z1 * sb;
      final z2 = y[i] * sb + z1 * cb;
      final s = 1 / (1 - z2 * _lens);
      px[i] = centre.dx + x1 * radius * s;
      py[i] = centre.dy - y2 * radius * s;
      depth[i] = z2;
      scale[i] = s;
    }
    order.sort((p, q) => depth[p].compareTo(depth[q]));
  }
}

/// Everything the painter reads that does not change per frame: the two
/// lattices, the colour dealt to each ray, and paints and shaders made
/// once. Shaders are built in UNIT space (radius one) and the canvas is
/// scaled to size them, so a pulsing core never compiles a gradient.
class _SphereScene {
  _SphereScene(int rays, List<Color> colours)
    : rays = _Lattice(rays),
      cells = _Lattice(_cellCount),
      colours = colours,
      rayColour = List<int>.generate(rays, (i) => (i * 7919) % colours.length);

  static const int _cellCount = 140;

  final _Lattice rays;
  final _Lattice cells;
  final List<Color> colours;
  final List<int> rayColour;

  /// Points along one ray: enough for the bends to read as a filament,
  /// few enough that a hundred rays stay one polyline call each.
  static const int segments = 10;

  /// Each ray's polyline, reused every frame: [segments] + 1 points of
  /// x,y. Rays are filaments, not rods -- see [_SpherePainter._paintRays].
  late final List<Float32List> filament = [
    for (var i = 0; i < rays.n; i++) Float32List((segments + 1) * 2),
  ];

  /// A phase per ray so the filaments do not wave in step.
  late final Float64List phase = Float64List.fromList([
    for (var i = 0; i < rays.n; i++) ((i * 2654435761) % 6283) / 1000.0,
  ]);

  /// The tints a ray is drawn in, per palette colour: whitened near the
  /// core, itself toward the tip, both at the alpha depth gives them.
  late final List<Color> nearInk = [
    for (final c in colours) Color.lerp(c, const Color(0xFFFFFFFF), 0.55)!,
  ];
  late final List<Color> tipInk = [
    for (final c in colours) Color.lerp(c, const Color(0xFFFFFFFF), 0.4)!,
  ];

  final Paint line = Paint()..strokeCap = StrokeCap.round;
  final Paint dots = Paint()..strokeCap = StrokeCap.round;
  final Paint fill = Paint();
  final Paint stroke = Paint()..style = PaintingStyle.stroke;

  static final Rect _unit = Rect.fromCircle(center: Offset.zero, radius: 1);

  final ui.Shader shellShader = RadialGradient(
    colors: [
      Palette.tech.withValues(alpha: 0.02),
      Palette.steel.withValues(alpha: 0.05),
      Palette.steel.withValues(alpha: 0.14),
    ],
    stops: const [0, 0.7, 1],
  ).createShader(_unit);

  final ui.Shader haloShader = RadialGradient(
    colors: [
      Palette.tech.withValues(alpha: 0.28),
      Palette.capsuleTree.withValues(alpha: 0.10),
      Palette.capsuleTree.withValues(alpha: 0),
    ],
    stops: const [0, 0.45, 1],
  ).createShader(_unit);

  final ui.Shader coreShader = RadialGradient(
    colors: [
      const Color(0xFFFFFFFF),
      Palette.tech,
      Palette.capsuleTree.withValues(alpha: 0.85),
    ],
    stops: const [0, 0.35, 1],
  ).createShader(_unit);
}

class _SpherePainter extends CustomPainter {
  _SpherePainter({
    required this.time,
    required this.scene,
    required this.pressure,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final _SphereScene scene;
  final double pressure;

  /// Depth buckets the shell's cells are batched into: one raw-points
  /// call per bucket instead of a circle per cell. Fine enough that a
  /// cell drifting across a bucket's edge does not visibly step.
  static const int _buckets = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide * 0.44;
    final a = t * 0.17;
    final b = 0.35 + math.sin(t * 0.09) * 0.25;

    _unitCircle(canvas, centre, radius, scene.shellShader);

    scene.cells.project(a, b, centre, radius);
    _paintCells(canvas, radius);

    final rays = scene.rays..project(a, b, centre, radius);
    // A small core: the filaments are the picture, and a plasma lamp's
    // electrode is a bead, not a sun. It still swells with pressure.
    final coreRadius = radius * (0.055 + 0.035 * pressure.clamp(0, 1));
    final pulse = 1 + 0.035 * math.sin(t * 2.6) + 0.02 * math.sin(t * 4.1);
    final core = coreRadius * pulse;

    // Back rays, then the core, then front rays: the core hides what is
    // behind it and is crossed by what is in front.
    _paintRays(canvas, centre, rays, core, t, back: true);
    _paintCore(canvas, centre, core, t);
    _paintRays(canvas, centre, rays, core, t, back: false);
    _paintRim(canvas, centre, radius);
  }

  /// A disc filled with a unit-space shader, sized by the canvas.
  void _unitCircle(Canvas canvas, Offset at, double r, ui.Shader shader) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(r);
    canvas.drawCircle(Offset.zero, 1, scene.fill..shader = shader);
    canvas.restore();
    scene.fill.shader = null;
  }

  void _paintCells(Canvas canvas, double radius) {
    // Only the back of the shell shows its cells: the front ones would
    // sit over the rays and turn the volume into a screen door. Points
    // batched by depth, sized and faded by how squarely each one faces
    // us -- and faded to nothing toward the rim, so a cell turning to
    // the front dims out rather than switching off.
    final cells = scene.cells;
    for (var bucket = 0; bucket < _buckets; bucket++) {
      final lo = -1 + bucket / _buckets;
      final hi = lo + 1 / _buckets;
      final pts = <double>[];
      for (var i = 0; i < cells.n; i++) {
        final d = cells.depth[i];
        if (d >= 0 || d < lo || d >= hi) continue;
        pts
          ..add(cells.px[i])
          ..add(cells.py[i]);
      }
      if (pts.isEmpty) continue;
      final facing = -(lo + hi) / 2;
      scene.dots
        ..color = Palette.steel.withValues(alpha: 0.22 * facing)
        ..strokeWidth = radius * 0.045 * (0.5 + 0.5 * facing);
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(pts),
        scene.dots,
      );
    }
  }

  void _paintRays(
    Canvas canvas,
    Offset centre,
    _Lattice rays,
    double core,
    double t, {
    required bool back,
  }) {
    final line = scene.line;
    const n = _SphereScene.segments;
    for (final i in rays.order) {
      final d = rays.depth[i];
      if (back ? d >= 0 : d < 0) continue;
      final front = (d + 1) / 2;
      final alpha = 0.16 + 0.7 * front;
      final width = 0.5 + 1.1 * front;
      final tip = Offset(rays.px[i], rays.py[i]);
      final dir = tip - centre;
      final len = dir.distance;
      final ink = scene.rayColour[i];
      // A tip that passes in front of the core has no room for a
      // filament, but it is still a point on the shell and keeps its
      // dot: only the line is skipped, never the tip.
      final start = core * 0.92;
      if (len > start + 1) {
        // A filament, not a rod: the ray leaves the core's edge and
        // wanders sideways on its way to the shell, like the arc in a
        // plasma lamp reaching for a hand. Three sines along its length,
        // phased per ray and drifting with time, pinched to nothing at
        // both ends so it always leaves the core and always lands on its
        // tip.
        final unit = dir / len;
        final normal = Offset(-unit.dy, unit.dx);
        final span = len - start;
        final amp = span * 0.075 * (0.6 + 0.4 * front);
        final ph = scene.phase[i];
        final pts = scene.filament[i];
        for (var k = 0; k <= n; k++) {
          final s = k / n;
          final wave =
              math.sin(s * 5.1 + t * 2.3 + ph) * 0.55 +
              math.sin(s * 11.7 - t * 3.9 + ph * 2.1) * 0.32 +
              math.sin(s * 23.0 + t * 7.1 + ph * 3.7) * 0.13;
          final side = amp * math.sin(s * math.pi) * wave;
          final p = centre + unit * (start + span * s) + normal * side;
          pts[k * 2] = p.dx;
          pts[k * 2 + 1] = p.dy;
        }
        line.strokeWidth = width;
        line.color = scene.colours[ink].withValues(alpha: alpha * 0.85);
        canvas.drawRawPoints(ui.PointMode.polygon, pts, line);
        // The first stretch again, whitened: the arc is hottest at the
        // electrode.
        line.color = scene.nearInk[ink].withValues(alpha: alpha);
        canvas.drawRawPoints(
          ui.PointMode.polygon,
          Float32List.sublistView(pts, 0, (n ~/ 3 + 1) * 2),
          line,
        );
      }

      // The tip, with ITS OWN alpha and size from its exact depth: dots
      // batched by depth bucket stepped visibly as a tip crossed a
      // bucket's edge. A few dozen circles are cheaper than that step.
      final dot = (1.2 + 1.6 * front) * rays.scale[i];
      scene.fill.color = scene.colours[ink].withValues(alpha: alpha * 0.18);
      canvas.drawCircle(tip, dot * 3, scene.fill);
      scene.fill.color = scene.tipInk[ink].withValues(alpha: alpha);
      canvas.drawCircle(tip, dot, scene.fill);
    }
  }

  void _paintCore(Canvas canvas, Offset centre, double core, double t) {
    // Halo, body, two tilted rings: the rings make the core a ball, and
    // their counter-rotation is what says it is turning, not blinking.
    _unitCircle(canvas, centre, core * 2.6, scene.haloShader);
    _unitCircle(canvas, centre, core, scene.coreShader);
    final ring = scene.stroke
      ..strokeWidth = 1.1
      ..color = Palette.sample.withValues(alpha: 0.75);
    for (final (spin, tilt) in [(t * 0.9, 0.42), (-t * 0.7 + 1.3, 0.95)]) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(spin);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: core * 2.35,
          height: core * 2.35 * math.sin(tilt).abs(),
        ),
        ring,
      );
      canvas.restore();
    }
  }

  void _paintRim(Canvas canvas, Offset centre, double radius) {
    // The shell's edge: a glow outside, a hairline on it, both cool.
    final stroke = scene.stroke;
    for (var i = 4; i >= 1; i--) {
      stroke
        ..strokeWidth = 2.2
        ..color = Palette.tech.withValues(alpha: 0.035 * (5 - i));
      canvas.drawCircle(centre, radius + i * 1.6, stroke);
    }
    stroke
      ..strokeWidth = 1
      ..color = Palette.tech.withValues(alpha: 0.42);
    canvas.drawCircle(centre, radius, stroke);
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.scene != scene || old.pressure != pressure;
}
