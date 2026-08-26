/// Layout of the drill scene, in one place.
///
/// The camera, the rock and the rig all measure against these, so they cannot
/// live inside any one of them.
library;

import 'package:stratum_core/stratum_core.dart';

import '../tokens.dart';

/// Height of one ordinary metre of rock on screen.
const double layerHeight = 46;

/// Where the drill string starts, clear of the resource strip.
const double headTop = AppMetrics.resourceBar + 34;

/// Length of the string above the bit. It doubles as the charge gauge.
const double stringLength = 118;

/// The bit meets the rock here, so this is where the layer being drilled sits.
const double rockTop = headTop + stringLength + 14;

/// Nothing is drawn above the layer being drilled: broken rock is gone, and
/// what sits above the bit is the empty borehole it left. A layer that broke
/// this instant is the one exception -- it keeps sliding up out of view while
/// the camera catches up.
const int layersBelow = 4;

double heightOf(int layer) => PrototypeSimulation.spanOf(layer) * layerHeight;
