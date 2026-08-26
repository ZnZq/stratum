/// Layout of the drill scene, in one place.
///
/// The camera, the rock and the rig all measure against these, so they cannot
/// live inside any one of them.
library;

import 'package:stratum_core/stratum_core.dart';

/// Height of one ordinary metre of rock on screen.
const double layerHeight = 38;

/// Where the drill string starts, clear of the resource strip.
/// Below the head band, which holds every readout the rig used to sit among.
const double headTop = 74;

/// Length of the string above the bit. It doubles as the charge gauge.
///
/// Short: the rig is a row across the scene now, not a single column, and a
/// long string would push the rock down for no reading gained.
const double stringLength = 64;

/// One drill of the rig.
///
/// Narrow enough that the whole rig fits across the island: the point of
/// showing several is reading the count at a glance, which stops working the
/// moment they have to overlap.
/// A drill's footprint is [bitWidth] + [rigGap], and seven of them have to
/// clear the depth readout on one side and the tick on the other: 7 x 21 is
/// 147 of the 390 the design is laid out against, which leaves both alone.
const double pipeWidth = 14;
const double bitWidth = 18;
const double bitHeight = 16;
const double rigGap = 3;

/// How many drills are drawn at most.
///
/// The count runs to hundreds and the screen does not. Past this the rig stops
/// growing and the number on the upgrades screen carries the truth.
const int maxDrawnDrills = 7;

int drawnDrills(int owned) =>
    owned < 1 ? 1 : (owned > maxDrawnDrills ? maxDrawnDrills : owned);

/// The bit meets the rock here, so this is where the layer being drilled sits.
const double rockTop = headTop + stringLength + 14;

/// Nothing is drawn above the layer being drilled: broken rock is gone, and
/// what sits above the bit is the empty borehole it left. A layer that broke
/// this instant is the one exception -- it keeps sliding up out of view while
/// the camera catches up.
const int layersBelow = 4;

double heightOf(int layer) => PrototypeSimulation.spanOf(layer) * layerHeight;
